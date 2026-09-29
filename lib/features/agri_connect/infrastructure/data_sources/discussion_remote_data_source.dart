/// ============================================================
/// AGRI CONNECT — DISCUSSION REMOTE DATA SOURCE
/// ============================================================
///
/// Raw Supabase operations for discussions, posts, reactions and views.
/// `reply_count` / `view_count` are database-maintained — never written.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class DiscussionRemoteDataSource {
  final SupabaseClient _client;

  DiscussionRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _schema = 'agri_connect';

  static const String _discussionSelect = '''
    id, community_id, title, discussion_type, created_by, is_pinned,
    is_locked, is_active, view_count, reply_count, metadata, created_at,
    updated_at
  ''';

  static const String _postSelect = '''
    id, discussion_id, author_profile_id, parent_post_id, body, is_edited,
    edited_at, is_deleted, deleted_at, created_at, updated_at
  ''';

  // ── Discussions ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchDiscussions({
    String? communityId,
  }) async {
    try {
      var query = _client
          .schema(_schema)
          .from('discussions')
          .select(_discussionSelect)
          .eq('is_active', true);
      if (communityId != null && communityId.isNotEmpty) {
        query = query.eq('community_id', communityId);
      }
      final response = await query
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load discussions: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load discussions: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchDiscussionById(String discussionId) async {
    try {
      return await _client
          .schema(_schema)
          .from('discussions')
          .select(_discussionSelect)
          .eq('id', discussionId)
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load discussion: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load discussion: $e');
    }
  }

  Future<Map<String, dynamic>> insertDiscussion(
    Map<String, dynamic> data,
  ) async {
    try {
      return await _client
          .schema(_schema)
          .from('discussions')
          .insert(data)
          .select(_discussionSelect)
          .single();
    } on PostgrestException catch (e) {
      throw Exception('Failed to create discussion: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create discussion: $e');
    }
  }

  Future<void> setPinned({
    required String discussionId,
    required bool pinned,
  }) async {
    await _updateDiscussion(discussionId, {'is_pinned': pinned});
  }

  Future<void> setLocked({
    required String discussionId,
    required bool locked,
  }) async {
    await _updateDiscussion(discussionId, {'is_locked': locked});
  }

  Future<void> _updateDiscussion(String id, Map<String, dynamic> data) async {
    try {
      await _client
          .schema(_schema)
          .from('discussions')
          .update(data)
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update discussion: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update discussion: $e');
    }
  }

  // ── Views (event counts) ───────────────────────────────────

  Future<void> insertView({
    required String discussionId,
    String? profileId,
    String? entityId,
  }) async {
    try {
      await _client.schema(_schema).from('discussion_views').insert({
        'discussion_id': discussionId,
        if (profileId != null && profileId.isNotEmpty) 'profile_id': profileId,
        if (entityId != null && entityId.isNotEmpty) 'entity_id': entityId,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to record view: ${e.message}');
    } catch (e) {
      throw Exception('Failed to record view: $e');
    }
  }

  // ── Posts / replies ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchPosts({
    required String discussionId,
    String? parentPostId,
  }) async {
    try {
      var query = _client
          .schema(_schema)
          .from('posts')
          .select(_postSelect)
          .eq('discussion_id', discussionId)
          .eq('is_deleted', false);

      if (parentPostId == null) {
        query = query.isFilter('parent_post_id', null);
      } else {
        query = query.eq('parent_post_id', parentPostId);
      }

      final response = await query.order('created_at', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load posts: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load posts: $e');
    }
  }

  Future<Map<String, dynamic>> insertPost(Map<String, dynamic> data) async {
    try {
      return await _client
          .schema(_schema)
          .from('posts')
          .insert(data)
          .select(_postSelect)
          .single();
    } on PostgrestException catch (e) {
      throw Exception('Failed to create post: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  Future<Map<String, dynamic>> updatePost({
    required String postId,
    required String body,
  }) async {
    try {
      return await _client
          .schema(_schema)
          .from('posts')
          .update({
            'body': body,
            'is_edited': true,
            'edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', postId)
          .select(_postSelect)
          .single();
    } on PostgrestException catch (e) {
      throw Exception('Failed to edit post: ${e.message}');
    } catch (e) {
      throw Exception('Failed to edit post: $e');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _client
          .schema(_schema)
          .from('posts')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', postId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete post: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  // ── Post reactions (UPSERT) ────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchPostReactions(String postId) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('post_reactions')
          .select('profile_id, reaction')
          .eq('post_id', postId);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load reactions: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load reactions: $e');
    }
  }

  Future<void> upsertPostReaction({
    required String postId,
    required String profileId,
    required String reaction,
  }) async {
    try {
      await _client.schema(_schema).from('post_reactions').upsert({
        'post_id': postId,
        'profile_id': profileId,
        'reaction': reaction,
      }, onConflict: 'post_id,profile_id');
    } on PostgrestException catch (e) {
      throw Exception('Failed to react: ${e.message}');
    } catch (e) {
      throw Exception('Failed to react: $e');
    }
  }

  Future<void> removePostReaction({
    required String postId,
    required String profileId,
  }) async {
    try {
      await _client
          .schema(_schema)
          .from('post_reactions')
          .delete()
          .eq('post_id', postId)
          .eq('profile_id', profileId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to remove reaction: ${e.message}');
    } catch (e) {
      throw Exception('Failed to remove reaction: $e');
    }
  }
}
