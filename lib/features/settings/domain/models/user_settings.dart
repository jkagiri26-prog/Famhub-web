/// ============================================================
/// USER SETTINGS — Domain model for users.user_settings
/// ============================================================
///
/// 🎯 PURPOSE:
///   Represents the authenticated user's personal settings row.
///   Keyed by `profile_id` = users.profiles.id (NOT auth.users.id).
///
/// ❌ Does NOT:
///   - Depend on Flutter (pure domain model)
///   - Carry entity/workspace/business fields
/// ============================================================
library;

/// Allowed `users.user_settings.theme` values.
enum AppThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  final String value;

  const AppThemePreference(this.value);

  static AppThemePreference fromValue(String? value) {
    return AppThemePreference.values.firstWhere(
      (preference) => preference.value == value,
      orElse: () => AppThemePreference.system,
    );
  }

  String get label {
    switch (this) {
      case AppThemePreference.system:
        return 'System';
      case AppThemePreference.light:
        return 'Light';
      case AppThemePreference.dark:
        return 'Dark';
    }
  }
}

/// A row from `users.user_settings`.
class UserSettings {
  /// users.profiles.id — the canonical profile identity.
  final String profileId;

  /// `system | light | dark`.
  final AppThemePreference theme;

  /// BCP-47 language code (default `en`).
  final String language;

  /// Free-form notification preferences JSON (`{}` by default).
  final Map<String, dynamic> notificationPreferences;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserSettings({
    required this.profileId,
    required this.theme,
    required this.language,
    this.notificationPreferences = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    final rawPreferences = json['notification_preferences'];
    return UserSettings(
      profileId: (json['profile_id'] ?? '').toString(),
      theme: AppThemePreference.fromValue(json['theme']?.toString()),
      language: (json['language'] ?? 'en').toString(),
      notificationPreferences: rawPreferences is Map
          ? Map<String, dynamic>.from(rawPreferences)
          : const {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  UserSettings copyWith({
    AppThemePreference? theme,
    String? language,
    Map<String, dynamic>? notificationPreferences,
  }) {
    return UserSettings(
      profileId: profileId,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
