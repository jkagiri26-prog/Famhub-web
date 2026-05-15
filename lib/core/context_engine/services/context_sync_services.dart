class ContextSyncService {
  Future<Map<String, dynamic>> fetchUserContext() async {
    // 🚨 NEVER trust local state
    // Call Supabase RPC or profile endpoint

    return {
      'userId': 'server_user_id',
      'role': 'farmer',
      'entityId': 'farm_123',
    };
  }
}