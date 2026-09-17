/// ============================================================
/// SHELL THEME PROVIDER — Riverpod state management for ShellTheme
/// ============================================================
///
/// 🎯 PURPOSE:
///   Provides reactive ShellTheme to the entire app.
///   Supports runtime theme switching and brand configuration.
///
/// ✅ Domain-Agnostic:
///   - The shell palette model stays neutral and reusable
///   - FAMHUB brand colours are injected via [FamhubBrandTokens]
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

/// ============================================================
/// FAMHUB BRAND TOKENS — Central colour identity
/// ============================================================
///
/// Single source of truth for the FAMHUB accent. Changing these
/// values re-skins the entire app — no widget hardcodes the brand.
///
/// The previous purple-blue accent (#6366F1) is replaced with a
/// deep natural agriculture green. Dark mode uses a lighter tint
/// of the same hue so text/buttons keep accessible contrast on
/// dark surfaces.
class FamhubBrandTokens {
  const FamhubBrandTokens._();

  /// Primary brand green — deep natural agriculture green.
  static const Color green = Color(0xFF256D3A);

  /// Light-mode page background — very light warm green/neutral.
  static const Color greenBackground = Color(0xFFF3F7F0);

  /// Light-mode subtle green surface (inputs, chips, hovers).
  static const Color greenSurface = Color(0xFFEAF2E6);

  /// Light-mode green-tinted border / divider.
  static const Color greenBorder = Color(0xFFD9E4D3);

  /// Light-mode hover tint.
  static const Color greenHover = Color(0xFFEEF4EA);

  /// Light-mode status-bar foreground (green-neutral).
  static const Color statusTextLight = Color(0xFF4B5A4F);

  /// Dark-mode primary — accessible lighter tint of the brand green.
  static const Color greenDark = Color(0xFF7CCB97);

  /// Dark-mode page background — warm, green-tinted near-black.
  static const Color greenBackgroundDark = Color(0xFF0F1512);

  /// Dark-mode surface.
  static const Color greenSurfaceDark = Color(0xFF1A221C);

  /// Dark-mode surface variant.
  static const Color greenSurfaceVariantDark = Color(0xFF2A342C);

  /// Dark-mode border / divider.
  static const Color greenBorderDark = Color(0xFF334036);

  /// Dark-mode status-bar foreground.
  static const Color statusTextDark = Color(0xFF9DB3A2);
}

/// Provides the application's ShellTheme configuration.
///
/// The shell itself stays domain-agnostic; FAMHUB injects its brand
/// identity here through the centralized palette tokens above, which
/// flow into [ColorScheme] via [ShellTheme.toThemeData].
final shellThemeProvider = Provider<ShellTheme>((ref) {
  final light = ShellTheme.defaultLight.copyWith(
    name: 'FAMHUB Light',
    primary: FamhubBrandTokens.green,
    borderFocused: FamhubBrandTokens.green,
    background: FamhubBrandTokens.greenBackground,
    surfaceVariant: FamhubBrandTokens.greenSurface,
    border: FamhubBrandTokens.greenBorder,
    divider: FamhubBrandTokens.greenBorder,
    hover: FamhubBrandTokens.greenHover,
    navigationBg: const Color(0xFFFFFFFF),
    navigationHover: FamhubBrandTokens.greenHover,
    navigationSelectedBg: FamhubBrandTokens.green.withValues(alpha: 0.08),
    navigationSelectedText: FamhubBrandTokens.green,
    statusBarBg: FamhubBrandTokens.greenBackground,
    statusBarText: FamhubBrandTokens.statusTextLight,
  );

  final dark = ShellTheme.defaultDark.copyWith(
    name: 'FAMHUB Dark',
    primary: FamhubBrandTokens.greenDark,
    borderFocused: FamhubBrandTokens.greenDark,
    background: FamhubBrandTokens.greenBackgroundDark,
    surface: FamhubBrandTokens.greenSurfaceDark,
    surfaceVariant: FamhubBrandTokens.greenSurfaceVariantDark,
    border: FamhubBrandTokens.greenBorderDark,
    divider: FamhubBrandTokens.greenBorderDark,
    hover: FamhubBrandTokens.greenSurfaceVariantDark,
    tertiaryText: FamhubBrandTokens.statusTextDark,
    navigationBg: FamhubBrandTokens.greenSurfaceDark,
    navigationHover: FamhubBrandTokens.greenSurfaceVariantDark,
    navigationSelectedBg: FamhubBrandTokens.greenDark.withValues(alpha: 0.12),
    navigationSelectedText: FamhubBrandTokens.greenDark,
    statusBarBg: FamhubBrandTokens.greenBackgroundDark,
    statusBarText: FamhubBrandTokens.statusTextDark,
  );

  return ShellTheme(
    light: light,
    dark: dark,
    brand: const ShellBrand(
      name: 'FAMHUB',
      tagline: 'Your Complete Agricultural Platform',
    ),
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
