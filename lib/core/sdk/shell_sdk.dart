/// ============================================================
/// SHELL SDK — Public facade for shell/layout state
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// ✅ Responsibilities:
///   - Expose shell configuration and mode to feature modules
///   - Delegate to shell providers and sidebar controller
///   - Never expose shell providers directly to feature modules
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain UI
///   - Render widgets
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/shell/application/controllers/sidebar_controller.dart';
import 'package:famhub_app/core/providers/theme_provider.dart';
import 'package:famhub_app/core/theme/shell_theme_provider.dart';
import 'package:famhub_app/core/theme/shell_theme.dart';
import 'api/sdk_annotations.dart';
/// ============================================================
/// SHELL SDK
/// ============================================================
///
/// Feature modules use this instead of reading providers directly.
///
/// Usage:
///   final shell = ref.read(famhubShellSdkProvider);
///   shell.switchMode(ShellLayoutMode.focus);
///   shell.toggleSidebar();
///   final theme = shell.theme();
/// ============================================================
@PublicSdk()
class ShellSdk {
  final Ref _ref;

  ShellSdk(this._ref);

  /// Toggle the sidebar expanded state
  @SdkMethod(version: '1.0.0')
  void toggleSidebar() {
    _ref.read(sidebarControllerProvider.notifier).toggle();
  }

  /// Set sidebar expanded state
  @SdkMethod(version: '1.0.0')
  void setSidebarExpanded(bool expanded) {
    _ref.read(sidebarControllerProvider.notifier).setExpanded(expanded);
  }

  /// Get sidebar expanded state
  @SdkMethod(version: '1.0.0')
  bool sidebarExpanded() =>
      _ref.read(sidebarExpandedProvider);

  /// Get the current theme mode
  @SdkMethod(version: '1.0.0')
  ThemeMode themeMode() =>
      _ref.read(themeModeProvider);

  /// Switch the theme mode
  @SdkMethod(version: '1.0.0')
  void setThemeMode(ThemeMode mode) {
    _ref.read(themeModeProvider.notifier).set(mode);
  }

  /// Toggle between light and dark theme
  @SdkMethod(version: '1.0.0')
  void toggleTheme() {
    _ref.read(themeModeProvider.notifier).toggle();
  }

  /// Get the shell theme
  @SdkMethod(version: '1.0.0')
  ShellTheme theme() =>
      _ref.read(shellThemeProvider);

  /// Get the shell brand name
  @SdkMethod(version: '1.0.0')
  String brandName() =>
      _ref.read(shellThemeProvider).brand.name;

  /// Get the shell brand tagline
  @SdkMethod(version: '1.0.0')
  String? brandTagline() =>
      _ref.read(shellThemeProvider).brand.tagline;
}

/// ============================================================
/// PROVIDER: SHELL SDK
/// ============================================================
@SdkProvider()
final famhubShellSdkProvider = Provider<ShellSdk>((ref) {
  return ShellSdk(ref);
});
