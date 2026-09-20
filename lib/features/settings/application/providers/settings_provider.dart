/// ============================================================
/// SETTINGS PROVIDER — Single canonical Settings state
/// ============================================================
///
/// 🎯 PURPOSE:
///   One canonical Settings state consumed by the Settings UI.
///   Loads/creates `users.user_settings` for the authenticated
///   user's canonical profile id and applies the persisted theme to
///   the existing application theme provider.
///
/// ✅ Identity:
///   profile id comes from the existing SessionController profile
///   row (`users.profiles.id`) — never auth.users.id.
///
/// ❌ Does NOT:
///   - Create a second theme/localization system
///   - Depend on entity/workspace/active-context
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/theme/shell_theme_provider.dart';

import '../../domain/models/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../infrastructure/repositories/settings_repository_impl.dart';

/// Repository provider (data layer entry point).
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl();
});

/// Canonical Settings UI state.
class SettingsState {
  final UserSettings? settings;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const SettingsState({
    this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  SettingsState copyWith({
    UserSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // Keep the canonical state in sync with the session: load once an
    // authenticated profile is available, reset on sign-out.
    ref.listen(sessionProvider, (previous, next) {
      final profileId = next.profile?['id']?.toString();
      if (next is AuthenticatedSession &&
          profileId != null &&
          profileId.isNotEmpty) {
        if (state.settings?.profileId != profileId) {
          Future.microtask(load);
        }
      } else if (!next.isAuthenticated) {
        state = const SettingsState();
      }
    });

    return const SettingsState();
  }

  /// users.profiles.id from the existing session architecture.
  String? get _profileId {
    final session = ref.read(sessionProvider);
    if (session is! AuthenticatedSession) return null;
    final id = session.profile?['id']?.toString();
    return (id == null || id.isEmpty) ? null : id;
  }

  ThemeMode _toThemeMode(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  /// Load the persisted settings, creating the initial row when absent.
  /// Also restores the persisted theme into the existing theme provider.
  Future<void> load() async {
    final profileId = _profileId;
    if (profileId == null) {
      state = const SettingsState(
        error: 'Your profile is not available yet. Please try again.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final settings =
          await ref.read(settingsRepositoryProvider).getOrCreate(profileId);
      state = SettingsState(settings: settings);
      ref
          .read(themeModeProvider.notifier)
          .set(_toThemeMode(settings.theme));
    } on SettingsException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'We could not load your settings. Please try again.',
      );
    }
  }

  /// Persist the theme and apply it to the app immediately (optimistic),
  /// reverting on failure.
  Future<void> setTheme(AppThemePreference theme) async {
    final current = state.settings;
    if (current == null || current.theme == theme) return;

    final previousMode = ref.read(themeModeProvider);
    ref.read(themeModeProvider.notifier).set(_toThemeMode(theme));
    state = state.copyWith(
      settings: current.copyWith(theme: theme),
      isSaving: true,
      clearError: true,
    );

    try {
      final updated = await ref
          .read(settingsRepositoryProvider)
          .updateSettings(profileId: current.profileId, theme: theme);
      state = SettingsState(settings: updated);
    } on SettingsException catch (e) {
      ref.read(themeModeProvider.notifier).set(previousMode);
      state = SettingsState(settings: current, error: e.message);
    } catch (_) {
      ref.read(themeModeProvider.notifier).set(previousMode);
      state = SettingsState(
        settings: current,
        error: 'We could not save your changes. Please try again.',
      );
    }
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);
