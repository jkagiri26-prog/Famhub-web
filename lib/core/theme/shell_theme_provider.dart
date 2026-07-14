/// ============================================================
/// SHELL THEME PROVIDER — Riverpod state management for ShellTheme
/// ============================================================
///
/// 🎯 PURPOSE:
///   Provides reactive ShellTheme to the entire app.
///   Supports runtime theme switching and brand configuration.
///
/// ✅ Domain-Agnostic:
///   - Default theme uses neutral palette (no agriculture)
///   - Brand colors injected via configuration, not hardcoded
///   - Supports any domain: FAMHUB, FactoryERP, Social, Healthcare, etc.
///
/// ✅ Usage for any domain:
///   ```dart
///   final shellTheme = ref.watch(shellThemeProvider);
///   final themeMode = ref.watch(themeModeProvider);
///   ```
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shell_theme.dart';

/// Provides the application's ShellTheme configuration.
/// Defaults to neutral domain-agnostic palette.
final shellThemeProvider = Provider<ShellTheme>((ref) {
  return const ShellTheme(
    light: ShellTheme.defaultLight,
    dark: ShellTheme.defaultDark,
  );
});

/// Manages the current ThemeMode (light / dark / system).
/// Defaults to ThemeMode.system so the app follows the OS setting.
///
/// To change the theme mode at runtime:
/// ```dart
/// ref.read(themeModeProvider.notifier).toggle();
/// ref.read(themeModeProvider.notifier).set(ThemeMode.dark);
/// ```
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void set(ThemeMode mode) => state = mode;

  void toggle() {
    // Toggle between light and dark only (no system mode in manual toggle)
    state = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system => ThemeMode.dark,
    };
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
