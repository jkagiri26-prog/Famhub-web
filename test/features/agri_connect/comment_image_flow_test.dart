/// ============================================================
/// AGRI CONNECT — COMMENT IMAGE FLOW TESTS
/// ============================================================
///
/// Covers comment/reply image attachments end to end against fakes:
///
///   Controller:
///   1. Text-only comment creation is unchanged — no upload, no lookup,
///      no client-side metadata write.
///   2. Creation with an image uploads through `upload_media` keyed by
///      the newly created post id (context is pinned in the contract
///      test); the relationship stays backend-owned (`post_media`).
///   3. Upload failure → `PostAttachException`: the comment is kept, the
///      failure is reported, and a retry uploads only (never re-creates
///      the comment, never deletes it to compensate).
///   4. Malformed/error upload responses surface at flow level.
///   5. Removal goes through `remove_post_media(p_post_id, p_file_id)`
///      only, and invalidates the lookup providers.
///
///   Widgets:
///   6. `PostTile` resolves and renders images for a comment and its
///      reply through the shared `agri_connect_post` lookup.
///   7. Lookup failure shows "Tap to retry" and recovers on tap.
///   8. Text-only composer flow stays upload-free (attach button present,
///      send does not touch the media system).
///   9. Edit dialog: mark image removed → Save runs the RPC only and
///      reports "Post updated." with the image gone from the tile.
///
/// Supabase is never initialized: repository, media data source and the
/// session profile are overridden in every test.
/// ============================================================
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/agri_connect/application/providers/agri_connect_providers.dart';
import 'package:famhub_app/features/agri_connect/application/providers/discussion_provider.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/discussion.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/post.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/reaction_summary.dart';
import 'package:famhub_app/features/agri_connect/domain/repositories/discussion_repository.dart';
import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/agri_connect_media.dart';
import 'package:famhub_app/features/agri_connect/presentation/pages/discussion_details_page.dart';
import 'package:famhub_app/features/agri_connect/presentation/widgets/post_tile.dart';

Uint8List _imageBytes() =>
    Uint8List.fromList(List<int>.generate(64, (i) => i % 251));

Discussion _discussion() => Discussion(
  id: 'd1',
  communityId: null,
  title: 'Watering schedule',
  createdBy: 'u1',
  metadata: const {},
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Post _post({
  String id = 'p1',
  String? parentId,
  String body = 'Hello',
  String author = 'u1',
}) => Post(
  id: id,
  discussionId: 'd1',
  authorProfileId: author,
  parentPostId: parentId,
  body: body,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class _FakeDiscussionRepository implements DiscussionRepository {
  _FakeDiscussionRepository([Discussion? discussion])
    : discussion = discussion ?? _discussion();

  Discussion discussion;
  final List<Post> posts = [];
  final List<String> createdBodies = [];
  final List<String> editPostCalls = [];
  final List<Map<String, dynamic>> metadataWrites = [];
  int recordViewCalls = 0;
  int _seq = 0;

  @override
  Future<List<Discussion>> fetchDiscussions({String? communityId}) async {
    return const [];
  }

  @override
  Future<Discussion?> fetchDiscussionById(String discussionId) async {
    return discussion;
  }

  @override
  Future<List<Post>> fetchPosts({
    required String discussionId,
    String? parentPostId,
  }) async {
    return [
      for (final p in posts)
        if (p.parentPostId == parentPostId) p,
    ];
  }

  @override
  Future<Post> createPost({
    required String discussionId,
    required String authorProfileId,
    String? parentPostId,
    required String body,
  }) async {
    _seq += 1;
    final post = Post(
      id: 'p$_seq',
      discussionId: discussionId,
      authorProfileId: authorProfileId,
      parentPostId: parentPostId,
      body: body,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    posts.add(post);
    createdBodies.add(body);
    return post;
  }

  @override
  Future<Post> editPost({required String postId, required String body}) async {
    editPostCalls.add('$postId|$body');
    final index = posts.indexWhere((p) => p.id == postId);
    if (index >= 0) {
      final old = posts[index];
      posts[index] = Post(
        id: old.id,
        discussionId: old.discussionId,
        authorProfileId: old.authorProfileId,
        parentPostId: old.parentPostId,
        body: body,
        isEdited: true,
        editedAt: DateTime(2026, 1, 2),
        createdAt: old.createdAt,
        updatedAt: DateTime(2026, 1, 2),
        authorName: old.authorName,
      );
      return posts[index];
    }
    return _post(id: postId, body: body);
  }

  @override
  Future<void> recordView({
    required String discussionId,
    String? profileId,
  }) async {
    recordViewCalls += 1;
  }

  @override
  Future<ReactionSummary> fetchPostReactions({
    required String postId,
    required String profileId,
  }) async {
    return const ReactionSummary();
  }

  @override
  Future<void> updateDiscussionMetadata({
    required String discussionId,
    required Map<String, dynamic> metadata,
  }) async {
    metadataWrites.add(Map<String, dynamic>.of(metadata));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Unexpected repository call: ${invocation.memberName}');
  }
}

class _FakeMedia extends AgriConnectMediaDataSource {
  _FakeMedia()
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

  /// Entries per context id (post id for comment images).
  final Map<String, List<Map<String, String>>> entriesByContext = {};

  /// The `context` string every lookup received — must always be the
  /// single shared post context.
  final List<String> fetchedContexts = [];
  final List<String> uploadedPostIds = [];
  final List<({String postId, String fileId})> removeCalls = [];
  final List<String> edgeFnDeletes = [];
  Object? uploadError;
  Object? entriesError;
  Object? removalError;

  @override
  Future<List<Map<String, String>>> fetchMediaEntries({
    required String context,
    required String contextId,
  }) async {
    fetchedContexts.add(context);
    final error = entriesError;
    if (error != null) throw error;
    return entriesByContext[contextId] ?? const [];
  }

  @override
  Future<String> resolveDisplayUrl(Map<String, String> entry) async {
    return entry['url'] ?? 'https://signed.local/${entry['id']}';
  }

  @override
  Future<dynamic> uploadPostImage({
    required Uint8List bytes,
    required String fileName,
    required String postId,
  }) async {
    final error = uploadError;
    if (error != null) throw error;
    uploadedPostIds.add(postId);
    return {'success': true, 'files': <Object>[]};
  }

  @override
  Future<void> removePostMedia({
    required String postId,
    required String fileId,
  }) async {
    final error = removalError;
    if (error != null) throw error;
    removeCalls.add((postId: postId, fileId: fileId));
    // Mirror the RPC: the relationship row disappears.
    entriesByContext[postId] = [
      for (final e in entriesByContext[postId] ?? const <Map<String, String>>[])
        if (e['id'] != fileId) e,
    ];
  }

  @override
  Future<void> deleteMedia(String fileId) async {
    edgeFnDeletes.add(fileId);
    throw StateError(
      'delete_media (listing-specific) must never run for comment images',
    );
  }

  @override
  Future<void> deleteDiscussionMedia(String fileId) async {
    edgeFnDeletes.add(fileId);
    throw StateError(
      'delete_discussion_media must never run for comment images',
    );
  }
}

List<Override> _overrides(_FakeDiscussionRepository repo, _FakeMedia media) {
  return [
    discussionRepositoryProvider.overrideWithValue(repo),
    agriConnectMediaProvider.overrideWithValue(media),
    agriConnectProfileIdProvider.overrideWithValue('u1'),
  ];
}

/// Riverpod 3 auto-retries failed providers (`ProviderContainer
/// .defaultRetry`: up to 10 backoff attempts before surfacing the error).
/// Tests disable it so a failed lookup reaches the error state in one
/// fetch and call counts stay deterministic.
Duration? _noRetry(int retryCount, Object error) => null;

Future<void> _pumpDetailsPage(
  WidgetTester tester,
  List<Override> overrides,
) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: _noRetry,
      overrides: overrides,
      child: const MaterialApp(home: DiscussionDetailsPage(discussionId: 'd1')),
    ),
  );
  await tester.pumpAndSettle();
}

/// Flush the SnackBar hide timer so `testWidgets` (FakeAsync) ends with no
/// pending timers after asserting the SnackBar's content.
Future<void> _flushSnackBar(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

void main() {
  group('comment creation flow (controller)', () {
    late _FakeDiscussionRepository repo;
    late _FakeMedia media;
    late ProviderContainer container;

    setUp(() {
      repo = _FakeDiscussionRepository();
      media = _FakeMedia();
      container = ProviderContainer(overrides: _overrides(repo, media));
      addTearDown(container.dispose);
    });

    DiscussionController controller() =>
        container.read(discussionControllerProvider.notifier);

    test('text-only comment creation never touches the media system', () async {
      final post = await controller().createPost(
        discussionId: 'd1',
        body: 'Hello',
      );

      expect(post.body, 'Hello');
      expect(repo.createdBodies, ['Hello']);
      expect(media.uploadedPostIds, isEmpty);
      expect(media.removeCalls, isEmpty);
      expect(media.fetchedContexts, isEmpty);
      expect(
        repo.metadataWrites,
        isEmpty,
        reason: 'comments have no client-side metadata to write',
      );
      expect(media.edgeFnDeletes, isEmpty);
    });

    test(
      'creation with an image uploads keyed by the created post id',
      () async {
        final post = await controller().createPost(
          discussionId: 'd1',
          body: 'With image',
          image: _imageBytes(),
        );

        expect(media.uploadedPostIds, [post.id]);
        expect(repo.createdBodies, ['With image']);
        expect(
          repo.metadataWrites,
          isEmpty,
          reason:
              'the uploader registers agri_connect.post_media itself — the '
              'client never writes the relationship',
        );
        expect(media.edgeFnDeletes, isEmpty);
      },
    );

    test('upload failure keeps the comment and a retry uploads without '
        're-creating it', () async {
      media.uploadError = Exception('Upload failed: storage unavailable');

      await expectLater(
        controller().createPost(
          discussionId: 'd1',
          body: 'Kept comment',
          image: _imageBytes(),
        ),
        throwsA(
          isA<PostAttachException>()
              .having((e) => e.post.body, 'post body', 'Kept comment')
              .having(
                (e) => e.cause.toString(),
                'cause',
                contains('storage unavailable'),
              ),
        ),
      );
      expect(
        repo.posts,
        hasLength(1),
        reason: 'the created comment must never be deleted to compensate',
      );
      expect(media.edgeFnDeletes, isEmpty);
      final created = repo.posts.single;

      // Retry path: upload only, against the already-created post.
      media.uploadError = null;
      await container
          .read(discussionControllerProvider.notifier)
          .attachPostImage(postId: created.id, bytes: _imageBytes());

      expect(media.uploadedPostIds, [created.id]);
      expect(
        repo.posts,
        hasLength(1),
        reason: 'a retry must never create a duplicate comment',
      );
    });

    test(
      'malformed upload response surfaces as a post-attach failure',
      () async {
        media.uploadError = Exception(
          'Upload failed: Unexpected response from the server.',
        );

        await expectLater(
          controller().createPost(
            discussionId: 'd1',
            body: 'Malformed',
            image: _imageBytes(),
          ),
          throwsA(
            isA<PostAttachException>().having(
              (e) => e.cause.toString(),
              'cause',
              contains('Unexpected response from the server.'),
            ),
          ),
        );
        expect(repo.posts, hasLength(1));
      },
    );

    test('removePostImage calls remove_post_media and invalidates the '
        'lookup providers', () async {
      media.entriesByContext['p1'] = [
        {'id': 'f1', 'url': 'https://signed.local/f1'},
      ];
      await container.read(postMediaEntriesProvider('p1').future);
      expect(media.fetchedContexts, ['agri_connect_post']);

      await controller().removePostImage(postId: 'p1', fileId: 'f1');

      expect(media.removeCalls, [(postId: 'p1', fileId: 'f1')]);
      expect(
        media.entriesByContext['p1'],
        isEmpty,
        reason: 'the fake mirrors the RPC detaching the relationship',
      );
      expect(media.edgeFnDeletes, isEmpty);
      expect(
        repo.metadataWrites,
        isEmpty,
        reason: 'no client write precedes the RPC',
      );

      await container.read(postMediaEntriesProvider('p1').future);
      expect(
        media.fetchedContexts,
        hasLength(2),
        reason: 'the entries provider was invalidated and re-fetched',
      );
    });

    test(
      'removePostImage reports backend failures without claiming success',
      () async {
        media.removalError = Exception(
          'Image removal failed: post image not found',
        );

        await expectLater(
          controller().removePostImage(postId: 'p1', fileId: 'f1'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('post image not found'),
            ),
          ),
        );
        expect(media.removeCalls, isEmpty);
        expect(media.edgeFnDeletes, isEmpty);
      },
    );
  });

  group('comment image display (PostTile)', () {
    late _FakeDiscussionRepository repo;
    late _FakeMedia media;

    setUp(() {
      repo = _FakeDiscussionRepository();
      media = _FakeMedia();
    });

    testWidgets(
      'renders images for a comment and its reply through agri_connect_post',
      (tester) async {
        media.entriesByContext['p1'] = [
          {'id': 'f1', 'url': 'https://signed.local/f1'},
        ];
        media.entriesByContext['p2'] = [
          {'id': 'f2', 'url': 'https://signed.local/f2'},
        ];

        await tester.pumpWidget(
          ProviderScope(
            retry: _noRetry,
            overrides: _overrides(repo, media),
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    PostTile(
                      post: _post(id: 'p1', body: 'Top level'),
                    ),
                    PostTile(
                      post: _post(id: 'p2', parentId: 'p1', body: 'Nested'),
                      nested: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsNWidgets(2));
        expect(media.fetchedContexts, [
          'agri_connect_post',
          'agri_connect_post',
        ], reason: 'both comment and reply resolve through the shared context');
        expect(media.edgeFnDeletes, isEmpty);
      },
    );

    testWidgets('lookup failure shows tap-to-retry and recovers on tap', (
      tester,
    ) async {
      media.entriesByContext['p1'] = [
        {'id': 'f1', 'url': 'https://signed.local/f1'},
      ];
      media.entriesError = Exception('lookup down');

      await tester.pumpWidget(
        ProviderScope(
          retry: _noRetry,
          overrides: _overrides(repo, media),
          child: MaterialApp(
            home: Scaffold(
              body: PostTile(post: _post(id: 'p1')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Image unavailable. Tap to retry.'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      media.entriesError = null;
      await tester.tap(find.text('Image unavailable. Tap to retry.'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(
        media.fetchedContexts,
        hasLength(2),
        reason: 'the retry re-ran the context lookup',
      );
    });
  });

  group('comment composer and edit dialog (page)', () {
    testWidgets('text-only comment creation stays upload-free', (tester) async {
      final repo = _FakeDiscussionRepository();
      final media = _FakeMedia();
      await _pumpDetailsPage(tester, _overrides(repo, media));

      expect(repo.recordViewCalls, 1);
      expect(
        find.byTooltip('Attach image'),
        findsOneWidget,
        reason: 'the composer exposes image attachment',
      );

      await tester.enterText(find.byType(TextField).first, 'Looks good');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(repo.createdBodies, ['Looks good']);
      expect(
        media.uploadedPostIds,
        isEmpty,
        reason: 'a text-only comment must never upload anything',
      );
      expect(media.fetchedContexts.toSet(), {
        'agri_connect_discussion',
        'agri_connect_post',
      }, reason: 'only display lookups run — no other media calls');
      expect(find.text('Looks good'), findsWidgets);
    });

    testWidgets(
      'edit dialog removes the image through remove_post_media only',
      (tester) async {
        final repo = _FakeDiscussionRepository();
        repo.posts.add(_post(id: 'p1', body: 'With image'));
        final media = _FakeMedia();
        media.entriesByContext['p1'] = [
          {'id': 'f1', 'url': 'https://signed.local/f1'},
        ];
        await _pumpDetailsPage(tester, _overrides(repo, media));

        final tileEdit = find.descendant(
          of: find.byType(PostTile),
          matching: find.byTooltip('Edit'),
        );
        expect(tileEdit, findsOneWidget);
        await tester.tap(tileEdit);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);

        final imageTile = find.byKey(const ValueKey('comment_image_tile'));
        expect(imageTile, findsOneWidget);
        await tester.tap(
          find.descendant(of: imageTile, matching: find.byIcon(Icons.close)),
        );
        await tester.pump();
        expect(imageTile, findsNothing);
        expect(
          find.text('The image will be removed when you save.'),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Save'),
          ),
        );
        await tester.pumpAndSettle();

        expect(repo.editPostCalls, ['p1|With image']);
        expect(media.removeCalls, [(postId: 'p1', fileId: 'f1')]);
        expect(
          media.edgeFnDeletes,
          isEmpty,
          reason:
              'the listing-specific delete_media edge function is never '
              'used for comment images',
        );
        expect(
          repo.metadataWrites,
          isEmpty,
          reason: 'comment images have no client-side metadata write',
        );
        expect(find.text('Post updated.'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(PostTile),
            matching: find.byType(Image),
          ),
          findsNothing,
          reason: 'the removed image is gone from the comment',
        );

        await _flushSnackBar(tester);
      },
    );
  });
}
