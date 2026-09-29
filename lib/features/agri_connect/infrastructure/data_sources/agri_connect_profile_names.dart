/// ============================================================
/// AGRI CONNECT — PROFILE DISPLAY NAME RESOLVER
/// ============================================================
///
/// Resolves `users.profiles` display names for a set of profile ids.
/// Used to stamp `author_name` / `display_name` without PostgREST embeds
/// (cross-schema embeds depend on the schema cache).
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class AgriConnectProfileNames {
  final SupabaseClient _client;

  AgriConnectProfileNames(this._client);

  /// id → "first_name last_name".
  Future<Map<String, String>> resolve(Set<String> profileIds) async {
    final ids = profileIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final response = await _client
          .schema('users')
          .from('profiles')
          .select('id, first_name, last_name')
          .inFilter('id', ids);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final result = <String, String>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null) continue;
        final first = row['first_name']?.toString() ?? '';
        final last = row['last_name']?.toString() ?? '';
        final name = [first, last].where((s) => s.isNotEmpty).join(' ');
        result[id] = name.isEmpty ? 'Farmer' : name;
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  Future<String?> resolveOne(String profileId) async {
    final map = await resolve({profileId});
    return map[profileId];
  }
}
