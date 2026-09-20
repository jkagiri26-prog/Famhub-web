/// ============================================================
/// SETTINGS REPOSITORY — Application-facing contract
/// ============================================================
///
/// 🎯 PURPOSE:
///   Defines the Settings operations consumed by the application
///   layer. Implementations handle the data source specifics.
///
/// ❌ Does NOT:
///   - Expose a generic cross-user settings API (always keyed by the
///     authenticated user's canonical profile id)
/// ============================================================
library;

import '../models/user_settings.dart';

abstract class SettingsRepository {
  /// Load the current profile's settings, creating the initial row with
  /// backend defaults when none exists yet.
  Future<UserSettings> getOrCreate(String profileId);

  /// Persist a partial update and return the authoritative saved row.
  Future<UserSettings> updateSettings({
    required String profileId,
    AppThemePreference? theme,
    String? language,
    Map<String, dynamic>? notificationPreferences,
  });
}

/// Error surfaced to the UI. Raw Supabase/Postgres errors are never leaked.
class SettingsException implements Exception {
  final String message;

  const SettingsException(this.message);

  @override
  String toString() => 'SettingsException: $message';
}
