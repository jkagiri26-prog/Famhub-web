/// ============================================================
/// SETTINGS REMOTE DATA SOURCE
/// ============================================================
///
/// 🎯 PURPOSE:
///   Raw Supabase read/write for `users.user_settings`.
///   Layer: Repository → DataSource → Supabase.
///
/// ✅ Scoping:
///   Every operation is keyed by the canonical `profile_id`
///   (users.profiles.id). RLS enforces ownership via
///   `core.current_profile_id()`.
/// ============================================================
library;

import 'package:famhub_app/core/services/supabase_service.dart';

class SettingsRemoteDataSource {
  final SupabaseService _supabase;

  SettingsRemoteDataSource({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  static const String _table = 'user_settings';
  static const String _schema = 'users';

  /// Returns the current profile's settings row, or null when none exists.
  Future<Map<String, dynamic>?> fetchSettings(String profileId) async {
    final row = await _supabase
        .from(_table, schema: _schema)
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  /// Creates the initial settings row. Only `profile_id` is supplied so the
  /// database defaults populate theme/language/notifications/timestamps.
  Future<Map<String, dynamic>> insertSettings(String profileId) async {
    final row = await _supabase
        .from(_table, schema: _schema)
        .insert({'profile_id': profileId})
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  /// Updates the given columns and returns the authoritative saved row.
  Future<Map<String, dynamic>> updateSettings(
    String profileId,
    Map<String, dynamic> values,
  ) async {
    final row = await _supabase
        .from(_table, schema: _schema)
        .update(values)
        .eq('profile_id', profileId)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }
}
