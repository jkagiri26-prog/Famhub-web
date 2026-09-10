import 'package:famhub_app/core/services/supabase_service.dart';

class ContextSyncService {
  /// Fetch the canonical authenticated context from the backend.
  ///
  /// Canonical chain:
  ///   auth.uid()
  ///     → users.profiles (by auth_user_id)   → profileId
  ///     → core.entity_context_sessions (user_id = profileId, active)
  ///       → core.entities.id                 → entityId
  ///       → active_role_id / active_mode     → roleId / role
  ///
  /// Returns null when there is NO authenticated profile or NO active
  /// entity context — the caller represents that as explicitly
  /// unavailable. Fabricated/default identities are NEVER returned.
  ///
  /// Returns a map with keys (kept distinct, never interchangeable):
  ///   userId     = auth.users.id
  ///   profileId  = users.profiles.id
  ///   entityId   = core.entities.id (nullable)
  ///   roleId     = core.user_roles.id (nullable)
  ///   role       = operational mode (nullable)
  ///   tier       = 'free'
  Future<Map<String, dynamic>?> fetchUserContext() async {
    final authUserId = SupabaseService.instance.currentUserId;
    if (authUserId == null) return null;

    // 1) Resolve the profile for this auth user.
    Map<String, dynamic>? profile;
    try {
      profile = await SupabaseService.instance
          .from('profiles', schema: 'users')
          .select('id, role_id')
          .eq('auth_user_id', authUserId)
          .maybeSingle();
    } catch (_) {
      profile = null;
    }
    if (profile == null) return null;

    final profileId = profile['id']?.toString();
    if (profileId == null) return null;

    // 2) Resolve the active entity-context session (if any).
    Map<String, dynamic>? session;
    try {
      session = await SupabaseService.instance.client
          .schema('core')
          .from('entity_context_sessions')
          .select('entity_id, active_mode, active_role_id, business_profile_id')
          .eq('user_id', profileId)
          .eq('session_status', 'active')
          .order('is_default', ascending: false)
          .order('last_switched_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      session = null;
    }

    return {
      'userId': authUserId,
      'profileId': profileId,
      'entityId': session?['entity_id']?.toString(),
      'roleId': session?['active_role_id']?.toString() ??
          profile['role_id']?.toString(),
      'businessProfileId': session?['business_profile_id']?.toString(),
      'role': session?['active_mode']?.toString(),
      'tier': 'free',
    };
  }
}
