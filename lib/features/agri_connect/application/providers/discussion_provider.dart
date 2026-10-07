/// ============================================================
/// AGRI CONNECT — DISCUSSION PROVIDERS
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/discussion.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/reaction_summary.dart';
import '../../domain/enums/discussion_enums.dart';
import '../../domain/repositories/discussion_repository.dart';
import 'agri_connect_providers.dart';

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

  Future<Discussion> createDiscussion({
    String? communityId,
    required String title,
    DiscussionType type = DiscussionType.discussion,
  }) async {
    final discussion = await _repo.createDiscussion(
      communityId: communityId,
      title: title,
      type: type,
    );
    // Refresh both the source list and the public feed/forum list.
    ref.invalidate(discussionsProvider(communityId));
    if (communityId != null) ref.invalidate(discussionsProvider(null));
    ref.invalidate(discussionAuthorNamesProvider(communityId));
    ref.invalidate(discussionAuthorNamesProvider(null));
    return discussion;
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
