/// ============================================================
/// AGRI CONNECT — DISCUSSION PROVIDERS
/// ============================================================
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/discussion.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/reaction_summary.dart';
import '../../domain/enums/discussion_enums.dart';
import '../../domain/repositories/discussion_repository.dart';
import '../../infrastructure/data_sources/agri_connect_media.dart';
import 'agri_connect_providers.dart';

/// `communityId == null` → general public forum discussions only
/// (`community_id IS NULL`). Otherwise → that specific community's
/// discussions. Filtering happens in the query, not in the UI.
final discussionsProvider = FutureProvider.family<List<Discussion>, String?>((
  ref,
  communityId,
) async {
  return ref
      .watch(discussionRepositoryProvider)
      .fetchDiscussions(communityId: communityId);
});

final discussionDetailsProvider = FutureProvider.family<Discussion?, String>((
  ref,
  discussionId,
) async {
  return ref
      .watch(discussionRepositoryProvider)
      .fetchDiscussionById(discussionId);
});

final postsProvider =
    FutureProvider.family<
      List<Post>,
      ({String discussionId, String? parentId})
    >((ref, key) async {
      return ref
          .watch(discussionRepositoryProvider)
          .fetchPosts(
            discussionId: key.discussionId,
            parentPostId: key.parentId,
          );
    });

final postReactionsProvider = FutureProvider.family<ReactionSummary, String>((
  ref,
  postId,
) async {
  final profileId = ref.watch(agriConnectProfileIdProvider) ?? '';
  return ref
      .watch(discussionRepositoryProvider)
      .fetchPostReactions(postId: postId, profileId: profileId);
});

/// Short-lived signed URLs for a discussion's attached images (max 2).
///
/// Resolves through `media_get_by_context` (existing authorization flow);
/// entries that only carry a storage path are signed client-side against
/// the private `media` bucket — never a public URL, never a raw path.
/// Re-running this provider (invalidate / refresh / retry) re-signs, so an
/// expired URL is never reused. Only watch this for discussions whose
/// metadata references media — it issues one `media_get_by_context` call
/// per discussion (same pattern as Marketplace's `listingImageUrlsProvider`).
final discussionMediaUrlsProvider = FutureProvider.family<List<String>, String>(
  (ref, discussionId) async {
    final media = ref.watch(agriConnectMediaProvider);
    final entries = await media.fetchMediaEntries(
      context: AgriConnectMediaDataSource.discussionsContext,
      contextId: discussionId,
    );
    final urls = <String>[];
    for (final entry in entries) {
      if (urls.length >= 2) break;
      urls.add(await media.resolveDisplayUrl(entry));
    }
    return urls;
  },
);

/// Display names for the authors of a discussion list, resolved in one
/// batched request with the existing profile-name resolver.
final discussionAuthorNamesProvider =
    FutureProvider.family<Map<String, String>, String?>((
      ref,
      communityId,
    ) async {
      final discussions =
          ref.watch(discussionsProvider(communityId)).value ??
          const <Discussion>[];
      final authorIds = discussions
          .map((d) => d.createdBy)
          .where((id) => id.isNotEmpty)
          .toSet();
      if (authorIds.isEmpty) return const {};
      return ref.watch(agriConnectProfileNamesProvider).resolve(authorIds);
    });

/// Mutation controller for discussions, posts, reactions and views.
class DiscussionController extends Notifier<void> {
  DiscussionRepository get _repo => ref.read(discussionRepositoryProvider);

  @override
  void build() {}

  /// Create a discussion, then (optionally) attach up to 2 images through
  /// the existing media edge functions.
  ///
  /// Creation semantics are unchanged: `community_id` is only sent when
  /// [communityId] is non-empty (public forum → `community_id = null`).
  /// Images are uploaded against context `discussions` / the new discussion
  /// id, then their `media.files` ids are persisted in the existing
  /// `metadata` JSONB column as `media_file_ids`.
  ///
  /// Throws [DiscussionAttachException] when the discussion was created but
  /// the images could not be attached (uploaded media is rolled back).
  Future<Discussion> createDiscussion({
    String? communityId,
    required String title,
    DiscussionType type = DiscussionType.discussion,
    List<Uint8List> images = const [],
  }) async {
    final discussion = await _repo.createDiscussion(
      communityId: communityId,
      title: title,
      type: type,
    );
    ref.invalidate(discussionsProvider(communityId));
    ref.invalidate(discussionAuthorNamesProvider(communityId));
    if (images.isNotEmpty) {
      await _attachDiscussionImages(discussion, images);
    }
    return discussion;
  }

  /// Upload each image to the existing media system and persist their file
  /// ids on the discussion. On any failure the just-uploaded media is
  /// deleted again (best effort) so no orphaned private files remain.
  Future<void> _attachDiscussionImages(
    Discussion discussion,
    List<Uint8List> images,
  ) async {
    final media = ref.read(agriConnectMediaProvider);
    final uploadedIds = <String>[];
    try {
      for (final bytes in images) {
        await media.uploadDiscussionImage(
          bytes: bytes,
          fileName:
              'discussion_image_'
              '${DateTime.now().microsecondsSinceEpoch}'
              '_${bytes.lengthInBytes}.webp',
          discussionId: discussion.id,
        );
      }
      final entries = await media.fetchMediaEntries(
        context: AgriConnectMediaDataSource.discussionsContext,
        contextId: discussion.id,
      );
      uploadedIds.addAll(entries.map((e) => e['id']).whereType<String>());
      if (uploadedIds.isEmpty) {
        throw Exception('The uploaded images could not be linked.');
      }
      await _repo.updateDiscussionMetadata(
        discussionId: discussion.id,
        metadata: {...discussion.metadata, 'media_file_ids': uploadedIds},
      );
      ref.invalidate(discussionMediaUrlsProvider(discussion.id));
    } catch (e) {
      var orphans = uploadedIds;
      if (orphans.isEmpty) {
        // Upload failed midway — collect whatever did land for cleanup.
        try {
          final entries = await media.fetchMediaEntries(
            context: AgriConnectMediaDataSource.discussionsContext,
            contextId: discussion.id,
          );
          orphans = entries.map((x) => x['id']).whereType<String>().toList();
        } catch (_) {
          // Best effort only.
        }
      }
      for (final id in orphans) {
        try {
          await media.deleteMedia(id);
        } catch (_) {
          // Best effort only.
        }
      }
      throw DiscussionAttachException(discussion: discussion, cause: e);
    }
  }

  Future<void> setPinned({
    required String discussionId,
    required bool pinned,
  }) async {
    await _repo.setPinned(discussionId: discussionId, pinned: pinned);
    ref.invalidate(discussionDetailsProvider(discussionId));
  }

  Future<void> setLocked({
    required String discussionId,
    required bool locked,
  }) async {
    await _repo.setLocked(discussionId: discussionId, locked: locked);
    ref.invalidate(discussionDetailsProvider(discussionId));
  }

  Future<void> recordView(String discussionId) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    try {
      await _repo.recordView(discussionId: discussionId, profileId: profileId);
    } catch (_) {
      // Views are best-effort; a failed view event must not block reading.
    }
  }

  Future<Post> createPost({
    required String discussionId,
    String? parentPostId,
    required String body,
  }) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) {
      throw Exception('You must be signed in to post.');
    }
    final post = await _repo.createPost(
      discussionId: discussionId,
      authorProfileId: profileId,
      parentPostId: parentPostId,
      body: body,
    );
    ref.invalidate(postsProvider((discussionId: discussionId, parentId: null)));
    if (parentPostId != null) {
      ref.invalidate(
        postsProvider((discussionId: discussionId, parentId: parentPostId)),
      );
    }
    ref.invalidate(discussionDetailsProvider(discussionId));
    return post;
  }

  Future<void> editPost({
    required String discussionId,
    required String postId,
    required String body,
  }) async {
    await _repo.editPost(postId: postId, body: body);
    ref.invalidate(postsProvider((discussionId: discussionId, parentId: null)));
  }

  Future<void> deletePost({
    required String discussionId,
    required String postId,
  }) async {
    await _repo.deletePost(postId);
    ref.invalidate(postsProvider((discussionId: discussionId, parentId: null)));
    ref.invalidate(discussionDetailsProvider(discussionId));
  }

  Future<void> react({required String postId, required String reaction}) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) {
      throw Exception('You must be signed in to react.');
    }
    await _repo.setPostReaction(
      postId: postId,
      profileId: profileId,
      reaction: reaction,
    );
    ref.invalidate(postReactionsProvider(postId));
  }

  Future<void> removeReaction(String postId) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) return;
    await _repo.removePostReaction(postId: postId, profileId: profileId);
    ref.invalidate(postReactionsProvider(postId));
  }
}

final discussionControllerProvider =
    NotifierProvider<DiscussionController, void>(DiscussionController.new);

/// The discussion was created, but its image attachments failed (upload or
/// linking). Carries the created discussion so callers can still navigate
/// to it and inform the user — the text draft is never lost.
class DiscussionAttachException implements Exception {
  final Discussion discussion;
  final Object cause;

  const DiscussionAttachException({
    required this.discussion,
    required this.cause,
  });

  @override
  String toString() => 'Images could not be attached: $cause';
}
