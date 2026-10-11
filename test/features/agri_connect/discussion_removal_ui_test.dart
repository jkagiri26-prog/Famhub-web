/// ============================================================
/// AGRI CONNECT — DISCUSSION IMAGE REMOVAL UI TESTS
/// ============================================================
///
/// Widget coverage for removing a discussion image through the
/// `agri_connect.delete_discussion_media` RPC:
///
///   1. Edit dialog → remove tile → Save detaches via the RPC only —
///      never the listing-specific `delete_media` edge function and with
///      no client-side metadata write (the RPC owns that change).
///   2. When the RPC fails (e.g. a backend rule rejects the removal) the
///      dialog reports the failure instead of claiming success, no
///      metadata is written and the stored list still contains the image
///      — the UI must never show the image as already removed.
///   3. After a successful save the details page refreshes: SnackBar,
///      refetched discussion, re-resolved image URLs, image gone.
///   4. On the details page a failed RPC shows the backend error while
///      the image stays visible.
///
/// Supabase is never initialized: repository, media data source and the
/// session profile are overridden, so `Supabase.instance` is untouched.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/agri_connect/application/providers/agri_connect_providers.dart';
import 'package:famhub_app/features/agri_connect/application/providers/discussion_provider.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/discussion.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/post.dart';
import 'package:famhub_app/features/agri_connect/domain/repositories/discussion_repository.dart';
import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/agri_connect_media.dart';
import 'package:famhub_app/features/agri_connect/presentation/pages/discussion_details_page.dart';
import 'package:famhub_app/features/agri_connect/presentation/pages/edit_discussion_dialog.dart';

Discussion _discussion() => Discussion(
  id: 'd1',
  communityId: null,
  title: 'Watering schedule',
  createdBy: 'u1',
  metadata: const {
    'media_file_ids': ['file-1'],
  },
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Discussion _withMetadata(Discussion d, Map<String, dynamic> metadata) {
  return Discussion(
    id: d.id,
    communityId: d.communityId,
    title: d.title,
    type: d.type,
    createdBy: d.createdBy,
    isPinned: d.isPinned,
    isLocked: d.isLocked,
    isActive: d.isActive,
    viewCount: d.viewCount,
    replyCount: d.replyCount,
    metadata: metadata,
    createdAt: d.createdAt,
    updatedAt: d.updatedAt,
  );
}

class _FakeDiscussionRepository implements DiscussionRepository {
  _FakeDiscussionRepository(this.discussion);

  Discussion discussion;
  int fetchDetailsCalls = 0;
  int recordViewCalls = 0;
  final List<String> textSaves = [];
  final List<Map<String, dynamic>> metadataWrites = [];

  @override
  Future<List<Discussion>> fetchDiscussions({String? communityId}) async {
    return const [];
  }

  @override
  Future<Discussion?> fetchDiscussionById(String discussionId) async {
    fetchDetailsCalls += 1;
    return discussion;
  }

  @override
  Future<List<Post>> fetchPosts({
    required String discussionId,
    String? parentPostId,
  }) async {
    return const [];
  }

  @override
  Future<void> updateDiscussion({
    required String discussionId,
    required String title,
    required String discussionType,
  }) async {
    textSaves.add('$title|$discussionType');
  }

  @override
  Future<void> updateDiscussionMetadata({
    required String discussionId,
    required Map<String, dynamic> metadata,
  }) async {
    metadataWrites.add(Map<String, dynamic>.of(metadata));
    discussion = _withMetadata(discussion, metadata);
  }

  @override
  Future<void> recordView({
    required String discussionId,
    String? profileId,
  }) async {
    recordViewCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Unexpected repository call: ${invocation.memberName}');
  }
}

class _FakeMedia extends AgriConnectMediaDataSource {
  _FakeMedia(this.entries)
    : super(
        // autoRefreshToken: false keeps GoTrue's refresh ticker (a
        // Timer.periodic) from becoming a pending fake timer that would
        // fail the testWidgets invariant check.
        SupabaseClient(
          'https://localhost',
          'anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  List<Map<String, String>> entries;
  final List<String> rpcRemovals = [];
  final List<String> edgeFnDeletes = [];
  int lookupCalls = 0;
  Exception? removalError;
  void Function(String fileId)? onRpcRemoved;

  @override
  Future<List<Map<String, String>>> fetchMediaEntries({
    required String context,
    required String contextId,
  }) async {
    lookupCalls += 1;
    return entries;
  }

  @override
  Future<String> resolveDisplayUrl(Map<String, String> entry) async {
    return entry['url'] ?? 'https://signed.local/${entry['id']}';
  }

  @override
  Future<void> deleteDiscussionMedia(String fileId) async {
    final error = removalError;
    if (error != null) throw error;
    rpcRemovals.add(fileId);
    onRpcRemoved?.call(fileId);
  }

  @override
  Future<void> deleteMedia(String fileId) async {
    edgeFnDeletes.add(fileId);
    throw StateError(
      'delete_media (listing-specific) must never run for discussions',
    );
  }
}

List<Override> _overrides(_FakeDiscussionRepository repo, _FakeMedia media) {
  return [
    discussionRepositoryProvider.overrideWithValue(repo),
    agriConnectMediaProvider.overrideWithValue(media),
    // Guest profile: no session (and therefore no Supabase) is needed.
    agriConnectProfileIdProvider.overrideWithValue(null),
  ];
}

/// Mirrors what the RPC does on success: the file id disappears from the
/// discussion's stored metadata and from the resolvable media entries.
void _simulateRpcRemoval(_FakeDiscussionRepository repo, _FakeMedia media) {
  media.onRpcRemoved = (fileId) {
    media.entries = [
      for (final e in media.entries)
        if (e['id'] != fileId) e,
    ];
    final ids = List<String>.of(repo.discussion.mediaFileIds)..remove(fileId);
    repo.discussion = _withMetadata(repo.discussion, {
      ...repo.discussion.metadata,
      'media_file_ids': ids,
    });
  };
}

Future<void> _pumpDialogHost(
  WidgetTester tester,
  List<Override> overrides,
  Discussion discussion,
  void Function(Object?) onResult,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  onResult(
                    await showDialog<Object>(
                      context: context,
                      builder: (_) =>
                          EditDiscussionDialog(discussion: discussion),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

Future<void> _pumpDetailsPage(
  WidgetTester tester,
  List<Override> overrides,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: DiscussionDetailsPage(discussionId: 'd1')),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byTooltip('Edit'), findsOneWidget);
}

Future<void> _removeExistingImage(WidgetTester tester, String fileId) async {
  final tile = find.byKey(ValueKey('agri_existing_$fileId'));
  expect(tile, findsOneWidget);
  await tester.tap(
    find.descendant(of: tile, matching: find.byIcon(Icons.close)),
  );
  await tester.pump();
  expect(find.byKey(ValueKey('agri_existing_$fileId')), findsNothing);
}

Finder _saveButton() =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text('Save'));

/// Flush the SnackBar hide timer so `testWidgets` (FakeAsync) ends with no
/// pending timers after asserting the SnackBar's content.
Future<void> _flushSnackBar(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

void main() {
  group('edit discussion dialog', () {
    testWidgets(
      'removing an image detaches via delete_discussion_media with no '
      'metadata write',
      (tester) async {
        final repo = _FakeDiscussionRepository(_discussion());
        final media = _FakeMedia([
          {'id': 'file-1', 'url': 'https://signed.local/file-1'},
        ]);
        _simulateRpcRemoval(repo, media);

        Object? result;
        await _pumpDialogHost(
          tester,
          _overrides(repo, media),
          repo.discussion,
          (r) => result = r,
        );

        await _removeExistingImage(tester, 'file-1');
        await tester.tap(_saveButton());
        await tester.pumpAndSettle();

        expect(result, editDiscussionSaved);
        expect(media.rpcRemovals, ['file-1']);
        expect(
          media.edgeFnDeletes,
          isEmpty,
          reason:
              'the listing-specific delete_media edge function is never '
              'used for discussions',
        );
        expect(
          repo.metadataWrites,
          isEmpty,
          reason:
              'the RPC owns the metadata change — no client write '
              'happens ahead of it',
        );
        expect(repo.textSaves, ['Watering schedule|discussion']);
        expect(repo.discussion.mediaFileIds, isEmpty);
      },
    );

    testWidgets(
      'RPC failure reports the backend error instead of claiming success',
      (tester) async {
        final repo = _FakeDiscussionRepository(_discussion());
        final media = _FakeMedia([
          {'id': 'file-1', 'url': 'https://signed.local/file-1'},
        ]);
        media.removalError = Exception(
          'Media removal failed: cannot remove the last attached image',
        );

        Object? result;
        await _pumpDialogHost(
          tester,
          _overrides(repo, media),
          repo.discussion,
          (r) => result = r,
        );

        await _removeExistingImage(tester, 'file-1');
        await tester.tap(_saveButton());
        await tester.pumpAndSettle();

        expect(result, isA<DiscussionEditException>());
        final failure = result! as DiscussionEditException;
        expect(failure.textSaved, isTrue);
        expect(failure.mediaSaved, isFalse);
        expect(failure.stage, DiscussionMediaStage.detach);
        expect(
          failure.userMessage,
          contains('removing an old image did not complete'),
        );
        expect(
          failure.userMessage,
          contains('cannot remove the last attached image'),
        );
        expect(
          repo.metadataWrites,
          isEmpty,
          reason:
              'no metadata write happens before the RPC, so a failed '
              'RPC leaves the stored list untouched',
        );
        expect(media.rpcRemovals, isEmpty);
        expect(media.edgeFnDeletes, isEmpty);
        expect(repo.discussion.mediaFileIds, [
          'file-1',
        ], reason: 'the image must still be stored after a failed removal');
      },
    );
  });

  group('discussion details page', () {
    testWidgets(
      'refreshes discussion, image URLs and page after a successful removal',
      (tester) async {
        final repo = _FakeDiscussionRepository(_discussion());
        final media = _FakeMedia([
          {'id': 'file-1', 'url': 'https://signed.local/file-1'},
        ]);
        _simulateRpcRemoval(repo, media);

        await _pumpDetailsPage(tester, _overrides(repo, media));
        expect(repo.recordViewCalls, 1);
        expect(find.byType(Image), findsWidgets);
        final detailsBefore = repo.fetchDetailsCalls;
        final lookupsBefore = media.lookupCalls;

        await tester.tap(find.byTooltip('Edit'));
        await tester.pumpAndSettle();
        await _removeExistingImage(tester, 'file-1');
        await tester.tap(_saveButton());
        await tester.pumpAndSettle();

        expect(find.text('Discussion updated.'), findsOneWidget);
        expect(media.rpcRemovals, ['file-1']);
        expect(media.edgeFnDeletes, isEmpty);
        expect(repo.metadataWrites, isEmpty);
        expect(repo.discussion.mediaFileIds, isEmpty);

        expect(
          repo.fetchDetailsCalls,
          greaterThan(detailsBefore),
          reason: 'the discussion is refetched after a removal',
        );
        expect(
          media.lookupCalls,
          greaterThan(lookupsBefore),
          reason: 'signed image URLs are re-resolved after a removal',
        );
        expect(
          find.byType(Image),
          findsNothing,
          reason: 'the removed image is gone from the page',
        );

        await _flushSnackBar(tester);
      },
    );

    testWidgets(
      'failed removal shows the backend error and keeps the image visible',
      (tester) async {
        final repo = _FakeDiscussionRepository(_discussion());
        final media = _FakeMedia([
          {'id': 'file-1', 'url': 'https://signed.local/file-1'},
        ]);
        media.removalError = Exception(
          'Media removal failed: cannot remove the last attached image',
        );

        await _pumpDetailsPage(tester, _overrides(repo, media));
        expect(find.byType(Image), findsWidgets);

        await tester.tap(find.byTooltip('Edit'));
        await tester.pumpAndSettle();
        await _removeExistingImage(tester, 'file-1');
        await tester.tap(_saveButton());
        await tester.pumpAndSettle();

        expect(
          find.textContaining('removing an old image did not complete'),
          findsOneWidget,
        );
        expect(
          find.textContaining('cannot remove the last attached image'),
          findsOneWidget,
        );
        expect(repo.metadataWrites, isEmpty);
        expect(repo.discussion.mediaFileIds, ['file-1']);
        expect(media.rpcRemovals, isEmpty);
        expect(
          find.byType(Image),
          findsWidgets,
          reason: 'a failed RPC must never show the image as removed',
        );

        await _flushSnackBar(tester);
      },
    );
  });
}
