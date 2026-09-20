/// ============================================================
/// SETTINGS REPOSITORY IMPLEMENTATION
/// ============================================================
///
/// 🎯 PURPOSE:
///   Bridge between the domain SettingsRepository contract and the
///   Supabase data source. Handles first-time initialization, partial
///   updates and friendly error conversion.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../data_sources/settings_remote_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsRemoteDataSource _dataSource;

  SettingsRepositoryImpl({SettingsRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? SettingsRemoteDataSource();

  @override
  Future<UserSettings> getOrCreate(String profileId) async {
    try {
      final existing = await _dataSource.fetchSettings(profileId);
      if (existing != null) return UserSettings.fromJson(existing);

      final created = await _dataSource.insertSettings(profileId);
      return UserSettings.fromJson(created);
    } on PostgrestException catch (e) {
      // Unique-violation race: a concurrent call created the row first.
      if (e.code == '23505') {
        final refetched = await _dataSource.fetchSettings(profileId);
        if (refetched != null) return UserSettings.fromJson(refetched);
      }
      throw const SettingsException(
        'We could not load your settings. Please try again.',
      );
    } catch (_) {
      throw const SettingsException(
        'We could not load your settings. Please try again.',
      );
    }
  }

  @override
  Future<UserSettings> updateSettings({
    required String profileId,
    AppThemePreference? theme,
    String? language,
    Map<String, dynamic>? notificationPreferences,
  }) async {
    final values = <String, dynamic>{};
    if (theme != null) values['theme'] = theme.value;
    if (language != null) values['language'] = language;
    if (notificationPreferences != null) {
      values['notification_preferences'] = notificationPreferences;
    }

    if (values.isEmpty) {
      final existing = await _dataSource.fetchSettings(profileId);
      if (existing != null) return UserSettings.fromJson(existing);
      throw const SettingsException('Nothing to update.');
    }

    try {
      final updated = await _dataSource.updateSettings(profileId, values);
      return UserSettings.fromJson(updated);
    } catch (_) {
      throw const SettingsException(
        'We could not save your changes. Please try again.',
      );
    }
  }
}
