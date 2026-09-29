/// ============================================================
/// AGRI CONNECT — DISCUSSION REPOSITORY CONTRACT
/// ============================================================
///
/// Discussions, posts, replies, reactions and view events.
/// `reply_count` / `view_count` are database-maintained — never written.
/// ============================================================
library;

import '../entities/discussion.dart';
import '../entities/post.dart';
import '../entities/reaction_summary.dart';
import '../enums/discussion_enums.dart';

abstract class DiscussionRepository {
  Future<List<Discussion>> fetchDiscussions({String? communityId});

  Future<Discussion?> fetchDiscussionById(String discussionId);

  Future<Discussion> createDiscussion({
    String? communityId,
    required String title,
    DiscussionType type = DiscussionType.discussion,
    Map<String, dynamic> metadata = const {},
  });

  /// Pin/unpin where authorized (backend-enforced).
  Future<void> setPinned({required String discussionId, required bool pinned});

  /// Lock/unlock where authorized (backend-enforced).
  Future<void> setLocked({required String discussionId, required bool locked});

  /// Record a view event. `profileId` is null for guests; the backend
  /// maintains `view_count` automatically.
  Future<void> recordView({required String discussionId, String? profileId});

  // ── Posts / replies ────────────────────────────────────────
  Future<List<Post>> fetchPosts({
    required String discussionId,
    String? parentPostId,
  });

  Future<Post> createPost({
    required String discussionId,
    required String authorProfileId,
    String? parentPostId,
    required String body,
  });

  Future<Post> editPost({required String postId, required String body});

  Future<void> deletePost(String postId);

  // ── Reactions (UPSERT: one reaction per user per post) ─────
  Future<ReactionSummary> fetchPostReactions({
    required String postId,
    required String profileId,
  });

  Future<void> setPostReaction({
    required String postId,
    required String profileId,
    required String reaction,
  });

  Future<void> removePostReaction({
    required String postId,
    required String profileId,
  });
}
