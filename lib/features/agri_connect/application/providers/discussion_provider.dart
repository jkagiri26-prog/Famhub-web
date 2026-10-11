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
      context: AgriConnectMediaDataSource.discussionLookupContext,
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
  /// Images are uploaded against the established `discussions` context /
  /// the new discussion id, then their `media.files` ids are persisted in
  /// the existing `metadata` JSONB column as `media_file_ids`.
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
        final payload = await media.uploadDiscussionImage(
          bytes: bytes,
          fileName:
              'discussion_image_'
              '${DateTime.now().microsecondsSinceEpoch}'
              '_${bytes.lengthInBytes}.webp',
          discussionId: discussion.id,
        );
        // Prefer ids returned by the upload response itself — no extra
        // round-trip and independent of `media_get_by_context` shape.
        for (final e in AgriConnectMediaDataSource.parseMediaEntries(payload)) {
          final id = e['id'];
          if (id != null && id.isNotEmpty && !uploadedIds.contains(id)) {
            uploadedIds.add(id);
          }
        }
      }
      if (uploadedIds.length < images.length) {
        // Fallback: resolve the ids through the context query.
        final entries = await media.fetchMediaEntries(
          context: AgriConnectMediaDataSource.discussionLookupContext,
          contextId: discussion.id,
        );
        final fetched = entries
            .map((e) => e['id'])
            .whereType<String>()
            .toList();
        if (fetched.isNotEmpty) {
          uploadedIds
            ..clear()
            ..addAll(fetched);
        }
      }
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
            context: AgriConnectMediaDataSource.discussionLookupContext,
            contextId: discussion.id,
          );
          orphans = entries.map((x) => x['id']).whereType<String>().toList();
        } catch (_) {
          // Best effort only.
        }
      }
      for (final id in orphans) {
        try {
          await media.deleteDiscussionMedia(id);
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

  Future<void> updateDiscussion({
    required String discussionId,
    required String title,
    required String discussionType,
  }) async {
    await _repo.updateDiscussion(
      discussionId: discussionId,
      title: title,
      discussionType: discussionType,
    );
    ref.invalidate(discussionDetailsProvider(discussionId));
  }

  /// Full edit of a discussion: title/type first (text), then a media
  /// reconciliation — removed ids are detached through the authorized
  /// `agri_connect.delete_discussion_media` RPC (the generic `delete_media`
  /// edge function is listing-specific) and retained/new ids form the
  /// remaining list.
  ///
  /// Safe ordering: text save → upload new → RPC detach removed → persist
  /// `media_file_ids` only when new images were added. The RPC itself
  /// removes the id from `metadata.media_file_ids`, so no metadata write
  /// happens ahead of it — a failed RPC leaves the list untouched instead
  /// of showing images as already removed. A failed upload/RPC/persist
  /// rolls back only the images uploaded during this save; retained files
  /// are never touched. On media failure the text save is kept and a
  /// [DiscussionEditException] reports exactly which parts completed — the
  /// caller must not claim total success.
  Future<void> editDiscussion({
    required String discussionId,
    required Discussion discussion,
    required String title,
    required String discussionType,
    required Set<String> retainedMediaIds,
    List<Uint8List> newImages = const [],
  }) async {
    final plan = planDiscussionMediaEdit(
      originalIds: discussion.mediaFileIds,
      retainedIds: retainedMediaIds,
      newImageCount: newImages.length,
    );
    await _repo.updateDiscussion(
      discussionId: discussionId,
      title: title,
      discussionType: discussionType,
    );
    ref.invalidate(discussionDetailsProvider(discussionId));
    ref.invalidate(discussionMediaUrlsProvider(discussionId));
    ref.invalidate(discussionsProvider(discussion.communityId));
    if (!plan.touchesMedia) return;

    final media = ref.read(agriConnectMediaProvider);
    final knownIds = <String>{...plan.retainedIds};
    try {
      await reconcileDiscussionMedia(
        plan: plan,
        newImages: newImages,
        upload: (bytes) async {
          final id = await _uploadDiscussionImage(
            media,
            bytes: bytes,
            discussionId: discussionId,
            knownIds: knownIds,
          );
          knownIds.add(id);
          return id;
        },
        persist: (ids) => _repo.updateDiscussionMetadata(
          discussionId: discussionId,
          metadata: {...discussion.metadata, 'media_file_ids': ids},
        ),
        detach: media.deleteDiscussionMedia,
      );
    } on DiscussionMediaPhaseException catch (e) {
      ref.invalidate(discussionDetailsProvider(discussionId));
      ref.invalidate(discussionMediaUrlsProvider(discussionId));
      throw DiscussionEditException(
        textSaved: true,
        mediaSaved: e.listPersisted,
        stage: e.stage,
        cause: e.cause,
      );
    }
    // Removal changed `metadata.media_file_ids` in the database (via the
    // RPC) and/or the signed URLs — refresh details, image URLs and the
    // discussion list so the UI shows the post-removal state.
    ref.invalidate(discussionDetailsProvider(discussionId));
    ref.invalidate(discussionMediaUrlsProvider(discussionId));
    ref.invalidate(discussionsProvider(discussion.communityId));
  }

  /// Upload one image and resolve its `media.files` id: prefer the id the
  /// upload response itself carries, fall back to the context query.
  Future<String> _uploadDiscussionImage(
    AgriConnectMediaDataSource media, {
    required Uint8List bytes,
    required String discussionId,
    required Set<String> knownIds,
  }) async {
    final payload = await media.uploadDiscussionImage(
      bytes: bytes,
      fileName:
          'discussion_image_${DateTime.now().microsecondsSinceEpoch}'
          '_${bytes.lengthInBytes}.webp',
      discussionId: discussionId,
    );
    for (final e in AgriConnectMediaDataSource.parseMediaEntries(payload)) {
      final id = e['id'];
      if (id != null && id.isNotEmpty && !knownIds.contains(id)) return id;
    }
    final entries = await media.fetchMediaEntries(
      context: AgriConnectMediaDataSource.discussionLookupContext,
      contextId: discussionId,
    );
    for (final e in entries) {
      final id = e['id'];
      if (id != null && id.isNotEmpty && !knownIds.contains(id)) return id;
    }
    throw Exception('The uploaded image could not be linked.');
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

/// The media sub-step of an edit save that failed, so error reporting can
/// identify the exact operation instead of a generic "media phase" failure.
enum DiscussionMediaStage {
  /// Uploading a newly picked image through `upload_media`.
  upload,

  /// Persisting the merged `metadata.media_file_ids` list.
  persist,

  /// Detaching a removed image through the
  /// `agri_connect.delete_discussion_media` RPC.
  detach;

  /// User-facing description of the failed sub-step.
  String get label => switch (this) {
    DiscussionMediaStage.upload => 'uploading a new image',
    DiscussionMediaStage.persist => 'saving the image list',
    DiscussionMediaStage.detach => 'removing an old image',
  };
}

/// A discussion edit saved its text (title/type) but the media portion did
/// not fully complete. [mediaSaved] distinguishes "nothing changed" from
/// "list saved, old-image cleanup failed"; [stage] names the sub-step that
/// threw. Callers must surface this instead of reporting total success.
class DiscussionEditException implements Exception {
  final bool textSaved;
  final bool mediaSaved;

  /// The media sub-step that failed, when the failure came from
  /// [reconcileDiscussionMedia] (null for untagged causes).
  final DiscussionMediaStage? stage;
  final Object cause;

  const DiscussionEditException({
    required this.textSaved,
    required this.mediaSaved,
    this.stage,
    required this.cause,
  });

  String get userMessage {
    if (mediaSaved) {
      return 'Title and type saved, but an old image could not be removed: '
          '$cause';
    }
    final phase = stage;
    if (phase == null) {
      return 'Title and type saved, but image changes were not '
          'fully completed: $cause';
    }
    return 'Title and type saved, but ${phase.label} did not complete: $cause';
  }

  @override
  String toString() => userMessage;
}

/// Media-phase failure raised by [reconcileDiscussionMedia].
/// [stage] is the sub-step that threw; [listPersisted] is true only when
/// `metadata.media_file_ids` was already written before the failure (the
/// current flow persists the list last, so failures report false).
class DiscussionMediaPhaseException implements Exception {
  final DiscussionMediaStage stage;
  final bool listPersisted;
  final Object cause;

  const DiscussionMediaPhaseException({
    required this.stage,
    required this.listPersisted,
    required this.cause,
  });

  @override
  String toString() => 'Media changes incomplete (${stage.label}): $cause';
}

/// Pure description of one edit's media changes, derived from the
/// discussion's `metadata.media_file_ids` (the source of truth) plus the
/// ids the author chose to keep. Never derived from image *loading* — a
/// failed URL fetch cannot shrink this list.
class DiscussionMediaEditPlan {
  final List<String> retainedIds;
  final List<String> removedIds;
  final int newImageCount;

  const DiscussionMediaEditPlan({
    required this.retainedIds,
    required this.removedIds,
    required this.newImageCount,
  });

  int get total => retainedIds.length + newImageCount;

  bool get touchesMedia => removedIds.isNotEmpty || newImageCount > 0;
}

/// Build the edit plan for a discussion's images (backend limit: 2 active
/// files). [retainedIds] contains only ids the author kept; any original
/// id not retained is scheduled for detach, and ids outside the original
/// list are ignored.
DiscussionMediaEditPlan planDiscussionMediaEdit({
  required List<String> originalIds,
  required Set<String> retainedIds,
  required int newImageCount,
}) {
  if (newImageCount < 0) {
    throw ArgumentError.value(newImageCount, 'newImageCount');
  }
  final retained = [
    for (final id in originalIds)
      if (retainedIds.contains(id)) id,
  ];
  final removed = [
    for (final id in originalIds)
      if (!retainedIds.contains(id)) id,
  ];
  final plan = DiscussionMediaEditPlan(
    retainedIds: retained,
    removedIds: removed,
    newImageCount: newImageCount,
  );
  if (plan.total > 2) {
    throw ArgumentError('A discussion can have at most 2 images.');
  }
  return plan;
}

/// Execute a media edit against the existing media functions:
/// upload new images → detach removed files through the authorized
/// `agri_connect.delete_discussion_media` RPC → persist the merged
/// `media_file_ids` only when new images were added.
///
/// The RPC owns the removal's metadata change, so no `persist` runs ahead
/// of it — when the RPC fails (e.g. a backend rule rejects the removal),
/// nothing was written and the old list still reflects reality. On any
/// failure only the images uploaded in this save are rolled back (retained
/// files are never touched) and a [DiscussionMediaPhaseException] with
/// `listPersisted: false` is thrown. A no-op plan performs no calls at
/// all. Every thrown [DiscussionMediaPhaseException] carries the
/// [DiscussionMediaStage] of the operation that failed.
Future<void> reconcileDiscussionMedia({
  required DiscussionMediaEditPlan plan,
  required List<Uint8List> newImages,
  required Future<String> Function(Uint8List bytes) upload,
  required Future<void> Function(List<String> mediaFileIds) persist,
  required Future<void> Function(String fileId) detach,
}) async {
  if (!plan.touchesMedia) return;
  final uploaded = <String>[];

  Future<void> rollbackUploads() async {
    for (final id in uploaded) {
      try {
        await detach(id);
      } catch (_) {
        // Best effort — never mask the original failure.
      }
    }
  }

  try {
    for (final bytes in newImages) {
      uploaded.add(await upload(bytes));
    }
  } catch (e) {
    await rollbackUploads();
    throw DiscussionMediaPhaseException(
      stage: DiscussionMediaStage.upload,
      listPersisted: false,
      cause: e,
    );
  }

  try {
    for (final id in plan.removedIds) {
      await detach(id);
    }
  } catch (e) {
    await rollbackUploads();
    throw DiscussionMediaPhaseException(
      stage: DiscussionMediaStage.detach,
      listPersisted: false,
      cause: e,
    );
  }

  if (uploaded.isEmpty) return; // Removal alone is fully handled by the RPC.
  try {
    await persist([...plan.retainedIds, ...uploaded]);
  } catch (e) {
    await rollbackUploads();
    throw DiscussionMediaPhaseException(
      stage: DiscussionMediaStage.persist,
      listPersisted: false,
      cause: e,
    );
  }
}
