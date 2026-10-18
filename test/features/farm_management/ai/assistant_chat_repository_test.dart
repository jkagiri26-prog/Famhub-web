import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/farm_management/domain/repositories/assistant_chat_repository.dart';
import 'package:famhub_app/features/farm_management/infrastructure/repositories/assistant_chat_repository_impl.dart';

/// Records every request and returns a canned JSON response. No network.
class _RecordingHttp extends http.BaseClient {
  _RecordingHttp(this._respond);

  final http.StreamedResponse Function(http.Request request) _respond;
  final List<http.Request> requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final http.Request typed = request as http.Request;
    requests.add(typed);
    final http.StreamedResponse response = _respond(typed);
    return http.StreamedResponse(
      response.stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: typed,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

http.StreamedResponse _json(Object? body, {int status = 200}) {
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
    status,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

SupabaseClient _clientFor(_RecordingHttp transport) {
  return SupabaseClient(
    'http://localhost:54321',
    'test-anon-key',
    httpClient: transport,
  );
}

void main() {
  group('SupabaseAssistantChatRepository ownership', () {
    test('creating a conversation never sends an owner id', () async {
      final _RecordingHttp transport = _RecordingHttp((http.Request request) {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/rest/v1/conversations'));
        expect(
          request.headers.values,
          contains('assistant'),
          reason: 'the assistant schema profile must be attached',
        );
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('user_id'), isFalse);
        expect(body.keys, unorderedEquals(<String>['title', 'context']));
        return _json(<String, dynamic>{
          'id': 'c-1',
          'title': body['title'],
          'context': body['context'],
          'created_at': '2026-10-18T10:00:00+00:00',
          'updated_at': '2026-10-18T10:00:00+00:00',
          'last_message_at': null,
        }, status: 201);
      });

      final SupabaseAssistantChatRepository repository =
          SupabaseAssistantChatRepository(_clientFor(transport));
      final AssistantConversation created = await repository.createConversation(
        title: 'When was my cow vaccinated?',
        contextMetadata: <String, dynamic>{'current_page': '/farm'},
      );

      expect(created.id, 'c-1');
      expect(created.title, 'When was my cow vaccinated?');
      expect(transport.requests, hasLength(1));
      expect(transport.requests.single.body, isNot(contains('user_id')));
    });

    test('appending a message sends only content columns', () async {
      final _RecordingHttp transport = _RecordingHttp((http.Request request) {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/rest/v1/messages'));
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body.keys,
          unorderedEquals(<String>['conversation_id', 'role', 'content']),
        );
        expect(body.containsKey('user_id'), isFalse);
        return _json(<Map<String, dynamic>>[], status: 201);
      });

      final SupabaseAssistantChatRepository repository =
          SupabaseAssistantChatRepository(_clientFor(transport));
      await repository.appendMessage(
        conversationId: 'c-1',
        role: 'farmer',
        text: 'My maize leaves are yellow.',
      );

      expect(transport.requests.single.body, isNot(contains('user_id')));
      expect(transport.requests.single.body, isNot(contains('"error_code"')));
    });

    test('renaming sends only the title', () async {
      final _RecordingHttp transport = _RecordingHttp((http.Request request) {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/rest/v1/conversations'));
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys, unorderedEquals(<String>['title']));
        return _json(<Map<String, dynamic>>[]);
      });

      final SupabaseAssistantChatRepository repository =
          SupabaseAssistantChatRepository(_clientFor(transport));
      await repository.renameConversation(
        conversationId: 'c-1',
        title: 'Herd health',
      );

      expect(transport.requests.single.body, contains('Herd health'));
      expect(transport.requests.single.body, isNot(contains('user_id')));
    });
  });

  group('SupabaseAssistantChatRepository reads', () {
    test(
      'lists conversations ordered by activity, without owner columns',
      () async {
        final _RecordingHttp transport = _RecordingHttp((http.Request request) {
          expect(request.method, 'GET');
          expect(request.url.path, contains('/rest/v1/conversations'));
          final String select = request.url.queryParameters['select'] ?? '';
          expect(select, isNot(contains('user_id')));
          final String order = request.url.queryParameters['order'] ?? '';
          expect(order, contains('last_message_at.desc.nullslast'));
          expect(order, contains('created_at.desc'));
          return _json(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'c-1',
              'title': 'Soil advice',
              'context': <String, dynamic>{'current_page': '/farm'},
              'created_at': '2026-10-17T09:00:00+00:00',
              'updated_at': '2026-10-18T09:00:00+00:00',
              'last_message_at': '2026-10-18T09:00:00+00:00',
            },
          ]);
        });

        final SupabaseAssistantChatRepository repository =
            SupabaseAssistantChatRepository(_clientFor(transport));
        final List<AssistantConversation> conversations = await repository
            .fetchConversations();

        expect(conversations, hasLength(1));
        expect(conversations.single.title, 'Soil advice');
        expect(conversations.single.lastMessageAt, isNotNull);
        expect(conversations.single.contextMetadata['current_page'], '/farm');
      },
    );

    test('reads messages oldest first with a bounded limit', () async {
      final _RecordingHttp transport = _RecordingHttp((http.Request request) {
        expect(request.method, 'GET');
        expect(request.url.path, contains('/rest/v1/messages'));
        expect(request.url.queryParameters['conversation_id'], 'eq.c-1');
        expect(request.url.queryParameters['limit'], '100');
        final String order = request.url.queryParameters['order'] ?? '';
        expect(order, contains('created_at.asc'));
        return _json(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'm-1',
            'conversation_id': 'c-1',
            'role': 'farmer',
            'content': 'Hello?',
            'error_code': null,
            'created_at': '2026-10-18T09:00:00+00:00',
          },
        ]);
      });

      final SupabaseAssistantChatRepository repository =
          SupabaseAssistantChatRepository(_clientFor(transport));
      final List<AssistantChatMessage> messages = await repository
          .fetchMessages('c-1');

      expect(messages, hasLength(1));
      expect(messages.single.role, 'farmer');
      expect(messages.single.text, 'Hello?');
      final String select =
          transport.requests.single.url.queryParameters['select'] ?? '';
      expect(select, isNot(contains('user_id')));
    });

    test('deleting targets a single conversation id', () async {
      final _RecordingHttp transport = _RecordingHttp((http.Request request) {
        expect(request.method, 'DELETE');
        expect(request.url.path, contains('/rest/v1/conversations'));
        expect(request.url.queryParameters['id'], 'eq.c-1');
        return _json(<Map<String, dynamic>>[]);
      });

      final SupabaseAssistantChatRepository repository =
          SupabaseAssistantChatRepository(_clientFor(transport));
      await repository.deleteConversation('c-1');

      expect(transport.requests.single.body, isNot(contains('user_id')));
    });
  });

  group('chat history migration', () {
    final String sql = File(
      'supabase/migrations/20261018000001_assistant_chat_history.sql',
    ).readAsStringSync();

    test('enables RLS with owner-only policies on both tables', () {
      expect(
        sql,
        contains(
          'ALTER TABLE "assistant"."conversations" ENABLE ROW LEVEL SECURITY',
        ),
      );
      expect(
        sql,
        contains(
          'ALTER TABLE "assistant"."messages" ENABLE ROW LEVEL SECURITY',
        ),
      );
      expect(sql, contains('CREATE POLICY "conversations_owner_all"'));
      expect(sql, contains('CREATE POLICY "messages_owner_all"'));
      expect(sql, contains('USING ("user_id" = "core"."auth_user_id"())'));
      expect(sql, contains('WITH CHECK ("user_id" = "core"."auth_user_id"())'));
    });

    test('derives and pins the owner in the schema itself', () {
      expect(sql, contains('DEFAULT "core"."auth_user_id"()'));
      expect(
        sql,
        contains('CHECK ("user_id" = "core"."auth_user_id"())'),
        reason: 'a client-supplied owner id for anyone else must be rejected',
      );
      // Messages can only attach to a conversation the same owner holds.
      expect(sql, contains('FOREIGN KEY ("conversation_id", "user_id")'));
      expect(sql, contains('ON DELETE CASCADE'));
    });

    test('revokes anon and PUBLIC table access', () {
      expect(
        sql,
        contains('REVOKE ALL ON TABLE "assistant"."conversations" FROM anon'),
      );
      expect(
        sql,
        contains('REVOKE ALL ON TABLE "assistant"."messages" FROM PUBLIC'),
      );
      expect(
        sql,
        isNot(
          contains(
            'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "assistant"."conversations" TO anon',
          ),
        ),
      );
    });

    test('stores module/route/workspace labels only, never ids', () {
      expect(sql, contains('"context" "jsonb"'));
      expect(sql, contains('module/route/workspace labels as metadata only'));
    });
  });

  group('SharedPreferencesAssistantChatPreferences', () {
    test('round-trips the last selected conversation id', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final SharedPreferencesAssistantChatPreferences prefs =
          SharedPreferencesAssistantChatPreferences();
      expect(await prefs.readLastConversationId(), isNull);

      await prefs.writeLastConversationId('c-42');
      final SharedPreferencesAssistantChatPreferences reopened =
          SharedPreferencesAssistantChatPreferences();
      expect(await reopened.readLastConversationId(), 'c-42');

      await prefs.writeLastConversationId(null);
      expect(await prefs.readLastConversationId(), isNull);
    });
  });
}
