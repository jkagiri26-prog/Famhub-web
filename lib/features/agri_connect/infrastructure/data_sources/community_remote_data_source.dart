/// ============================================================
/// AGRI CONNECT — COMMUNITY REMOTE DATA SOURCE
/// ============================================================
///
/// Raw Supabase operations for `agri_connect` community tables.
/// Creation goes through `create_community` RPC — never a direct
/// `communities` INSERT. Membership / join-request / invitation / rule
/// operations are direct table operations scoped by RLS.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityRemoteDataSource {
  final SupabaseClient _client;

  CommunityRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _schema = 'agri_connect';

  static const String _communitySelect = '''
    id, name, slug, description, community_type, visibility, entity_id,
    location_id, created_by, profile_image_file_id, is_active, is_verified,
    member_count, metadata, created_at, updated_at
  ''';

  // ── Discover ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchDiscoverableCommunities({
    String? searchQuery,
    String? type,
  }) async {
    try {
      var query = _client
          .schema(_schema)
          .from('communities')
          .select(_communitySelect)
          .eq('is_active', true);

      if (type != null && type.isNotEmpty) {
        query = query.eq('community_type', type);
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('name', '%${searchQuery.trim()}%');
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load communities: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load communities: $e');
    }
  }

  Future<List<String>> fetchMembershipCommunityIds(String profileId) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('community_members')
          .select('community_id')
          .eq('profile_id', profileId)
          .eq('status', 'active');
      return (response as List)
          .map((r) => (r as Map)['community_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load your communities: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load your communities: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCommunitiesByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    try {
      final response = await _client
          .schema(_schema)
          .from('communities')
          .select(_communitySelect)
          .inFilter('id', ids);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load communities: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load communities: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchCommunityById(String communityId) async {
    try {
      return await _client
          .schema(_schema)
          .from('communities')
          .select(_communitySelect)
          .eq('id', communityId)
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load community: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load community: $e');
    }
  }

  // ── Creation (RPC only) ────────────────────────────────────

  /// Creates a community via `agri_connect.create_community`.
  ///
  /// The backend derives the creator and bootstraps the owner membership.
  /// `PostgrestException` is deliberately not wrapped so callers can map
  /// error codes (e.g. unique slug violation).
  Future<Map<String, dynamic>?> createCommunity({
    required String name,
    required String slug,
    required String type,
    String? visibility,
    String? description,
    String? entityId,
    String? locationId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final response = await _client
        .schema(_schema)
        .rpc(
          'create_community',
          params: {
            'p_name': name,
            'p_slug': slug,
            'p_community_type': type,
            if (visibility != null) 'p_visibility': visibility,
            if (description != null && description.trim().isNotEmpty)
              'p_description': description.trim(),
            if (entityId != null && entityId.isNotEmpty)
              'p_entity_id': entityId,
            if (locationId != null && locationId.isNotEmpty)
              'p_location_id': locationId,
            'p_metadata': metadata,
          },
        );
    return _firstRow(response);
  }

  // ── Membership ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMembers(String communityId) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('community_members')
          .select()
          .eq('community_id', communityId)
          .eq('status', 'active')
          .order('joined_at', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load members: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load members: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchMembership({
    required String communityId,
    required String profileId,
  }) async {
    try {
      return await _client
          .schema(_schema)
          .from('community_members')
          .select()
          .eq('community_id', communityId)
          .eq('profile_id', profileId)
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load membership: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load membership: $e');
    }
  }

  Future<void> joinCommunity({
    required String communityId,
    required String profileId,
  }) async {
    try {
      await _client.schema(_schema).from('community_members').insert({
        'community_id': communityId,
        'profile_id': profileId,
        'status': 'active',
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to join community: ${e.message}');
    } catch (e) {
      throw Exception('Failed to join community: $e');
    }
  }

  Future<void> leaveCommunity({
    required String communityId,
    required String profileId,
  }) async {
    try {
      await _client
          .schema(_schema)
          .from('community_members')
          .update({'status': 'left'})
          .eq('community_id', communityId)
          .eq('profile_id', profileId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to leave community: ${e.message}');
    } catch (e) {
      throw Exception('Failed to leave community: $e');
    }
  }

  /// Rejoin a community the caller previously left.
  ///
  /// Updates the existing membership row (`left` → `pending`) by profile id —
  /// never an INSERT/upsert. Returns the updated row, or null when no matching
  /// `left` membership exists.
  Future<Map<String, dynamic>?> rejoinCommunity({
    required String communityId,
    required String profileId,
  }) async {
    try {
      return await _client
          .schema(_schema)
          .from('community_members')
          .update({
            'status': 'pending',
            'role': 'member',
            'joined_at': null,
            'invited_by': null,
            'approved_by': null,
            'approved_at': null,
            'requested_at': DateTime.now().toIso8601String(),
          })
          .eq('community_id', communityId)
          .eq('profile_id', profileId)
          .eq('status', 'left')
          .select()
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw Exception('Failed to rejoin community: ${e.message}');
    } catch (e) {
      throw Exception('Failed to rejoin community: $e');
    }
  }

  // ── Join requests ──────────────────────────────────────────

  Future<void> requestToJoin({
    required String communityId,
    required String profileId,
    String? message,
  }) async {
    try {
      await _client.schema(_schema).from('community_join_requests').insert({
        'community_id': communityId,
        'profile_id': profileId,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to submit join request: ${e.message}');
    } catch (e) {
      throw Exception('Failed to submit join request: $e');
    }
  }

  Future<void> cancelJoinRequest({
    required String communityId,
    required String profileId,
  }) async {
    try {
      await _client
          .schema(_schema)
          .from('community_join_requests')
          .update({'status': 'cancelled'})
          .eq('community_id', communityId)
          .eq('profile_id', profileId)
          .eq('status', 'pending');
    } on PostgrestException catch (e) {
      throw Exception('Failed to cancel join request: ${e.message}');
    } catch (e) {
      throw Exception('Failed to cancel join request: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchJoinRequests(
    String communityId,
  ) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('community_join_requests')
          .select()
          .eq('community_id', communityId)
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load join requests: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load join requests: $e');
    }
  }

  Future<void> reviewJoinRequest({
    required String requestId,
    required String status,
  }) async {
    try {
      await _client
          .schema(_schema)
          .from('community_join_requests')
          .update({
            'status': status,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to review join request: ${e.message}');
    } catch (e) {
      throw Exception('Failed to review join request: $e');
    }
  }

  // ── Invitations ────────────────────────────────────────────

  Future<void> createInvitation({
    required String communityId,
    String? invitedProfileId,
    String? invitedEmail,
  }) async {
    try {
      await _client.schema(_schema).from('community_invitations').insert({
        'community_id': communityId,
        if (invitedProfileId != null && invitedProfileId.isNotEmpty)
          'invited_profile_id': invitedProfileId,
        if (invitedEmail != null && invitedEmail.isNotEmpty)
          'invited_email': invitedEmail,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to create invitation: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create invitation: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyInvitations(
    String profileId,
  ) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('community_invitations')
          .select()
          .eq('invited_profile_id', profileId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load invitations: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load invitations: $e');
    }
  }

  Future<void> setInvitationStatus({
    required String invitationId,
    required String status,
  }) async {
    try {
      await _client
          .schema(_schema)
          .from('community_invitations')
          .update({'status': status})
          .eq('id', invitationId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update invitation: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update invitation: $e');
    }
  }

  // ── Rules ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchRules(String communityId) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('community_rules')
          .select()
          .eq('community_id', communityId)
          .eq('is_active', true)
          .order('rule_order', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load rules: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load rules: $e');
    }
  }

  Future<void> insertRule({
    required String communityId,
    required String title,
    String? description,
    required int order,
  }) async {
    try {
      await _client.schema(_schema).from('community_rules').insert({
        'community_id': communityId,
        'title': title,
        'rule_order': order,
        if (description != null && description.isNotEmpty)
          'description': description,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to create rule: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create rule: $e');
    }
  }

  Future<void> updateRule({
    required String ruleId,
    String? title,
    String? description,
    int? order,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (order != null) data['rule_order'] = order;
    if (data.isEmpty) return;
    try {
      await _client
          .schema(_schema)
          .from('community_rules')
          .update(data)
          .eq('id', ruleId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update rule: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update rule: $e');
    }
  }

  Future<void> deleteRule(String ruleId) async {
    try {
      await _client
          .schema(_schema)
          .from('community_rules')
          .delete()
          .eq('id', ruleId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete rule: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete rule: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────

  static Map<String, dynamic>? _firstRow(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List) {
      for (final item in response) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }
}
