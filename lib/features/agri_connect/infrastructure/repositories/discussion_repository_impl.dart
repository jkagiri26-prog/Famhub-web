/// ============================================================
/// AGRI CONNECT — DISCUSSION REPOSITORY IMPLEMENTATION
/// ============================================================
library;

import 'package:famhub_app/features/agri_connect/domain/entities/discussion.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/post.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/reaction_summary.dart';
import 'package:famhub_app/features/agri_connect/domain/enums/discussion_enums.dart';
import 'package:famhub_app/features/agri_connect/domain/repositories/discussion_repository.dart';
import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/agri_connect_profile_names.dart';
import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/discussion_remote_data_source.dart';

class DiscussionRepositoryImpl implements DiscussionRepository {
  final DiscussionRemoteDataSource _dataSource;
  final AgriConnectProfileNames _profileNames;

  DiscussionRepositoryImpl(this._dataSource, this._profileNames);

  /// `communityId == null` → general public forum discussions
  /// (`community_id IS NULL`). Otherwise → that community's discussions.
  @override
  Future<List<Discussion>> fetchDiscussions({String? communityId}) async {
    final rows = await _dataSource.fetchDiscussions(communityId: communityId);
    return rows.map(Discussion.fromJson).toList();
  }

  @override
  Future<Discussion?> fetchDiscussionById(String discussionId) async {
    final row = await _dataSource.fetchDiscussionById(discussionId);
    return row == null ? null : Discussion.fromJson(row);
  }

  @override
  Future<Discussion> createDiscussion({
    String? communityId,
    required String title,
    DiscussionType type = DiscussionType.discussion,
    Map<String, dynamic> metadata = const {},
  }) async {
    final row = await _dataSource.insertDiscussion({
      if (communityId != null && communityId.isNotEmpty)
        'community_id': communityId,
      'title': title,
      'discussion_type': type.name,
      'metadata': metadata,
    });
    return Discussion.fromJson(row);
  }

  @override
  Future<void> updateDiscussionMetadata({
    required String discussionId,
    required Map<String, dynamic> metadata,
  }) async {
    await _dataSource.updateDiscussionMetadata(
      discussionId: discussionId,
      metadata: metadata,
    );
  }

  @override
  Future<void> setPinned({
    required String discussionId,
    required bool pinned,
  }) async {
    await _dataSource.setPinned(discussionId: discussionId, pinned: pinned);
  }

  @override
  Future<void> setLocked({
    required String discussionId,
    required bool locked,
  }) async {
    await _dataSource.setLocked(discussionId: discussionId, locked: locked);
  }

  @override
  Future<void> recordView({
    required String discussionId,
    String? profileId,
  }) async {
    await _dataSource.insertView(
      discussionId: discussionId,
      profileId: profileId,
    );
  }

  @override
  Future<List<Post>> fetchPosts({
    required String discussionId,
    String? parentPostId,
  }) async {
    final rows = await _dataSource.fetchPosts(
      discussionId: discussionId,
      parentPostId: parentPostId,
    );
    final authorIds = rows
        .map((r) => r['author_profile_id']?.toString() ?? '')
        .toSet();
    final names = await _profileNames.resolve(authorIds);
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      final pid = map['author_profile_id']?.toString();
      if (pid != null && names.containsKey(pid)) {
        map['author_name'] = names[pid];
      }
      return Post.fromJson(map);
    }).toList();
  }

  @override
  Future<Post> createPost({
    required String discussionId,
    required String authorProfileId,
    String? parentPostId,
    required String body,
  }) async {
    final row = await _dataSource.insertPost({
      'discussion_id': discussionId,
      'author_profile_id': authorProfileId,
      if (parentPostId != null && parentPostId.isNotEmpty)
        'parent_post_id': parentPostId,
      'body': body,
    });
    return Post.fromJson(row);
  }

  @override
  Future<Post> editPost({required String postId, required String body}) async {
    final row = await _dataSource.updatePost(postId: postId, body: body);
    return Post.fromJson(row);
  }

  @override
  Future<void> deletePost(String postId) async {
    await _dataSource.deletePost(postId);
  }

  @override
  Future<ReactionSummary> fetchPostReactions({
    required String postId,
    required String profileId,
  }) async {
    final rows = await _dataSource.fetchPostReactions(postId);
    return _summarize(rows, profileId);
  }

  @override
  Future<void> setPostReaction({
    required String postId,
    required String profileId,
    required String reaction,
  }) async {
    await _dataSource.upsertPostReaction(
      postId: postId,
      profileId: profileId,
      reaction: reaction,
    );
  }

  @override
  Future<void> removePostReaction({
    required String postId,
    required String profileId,
  }) async {
    await _dataSource.removePostReaction(postId: postId, profileId: profileId);
  }

  ReactionSummary _summarize(
    List<Map<String, dynamic>> rows,
    String profileId,
  ) {
    final counts = <String, int>{};
    String? mine;
    for (final row in rows) {
      final reaction = row['reaction']?.toString() ?? '';
      final pid = row['profile_id']?.toString() ?? '';
      if (reaction.isEmpty) continue;
      counts[reaction] = (counts[reaction] ?? 0) + 1;
      if (pid == profileId) mine = reaction;
    }
    return ReactionSummary(counts: counts, myReaction: mine);
  }
}
