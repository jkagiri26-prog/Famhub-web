/// ============================================================
/// DARK THEME — Dark mode theme configuration
/// ============================================================
///
/// 🎯 PURPOSE:
///   Provides dark mode ThemeData using ShellTheme.
///   No hardcoded colors — everything comes from ShellTheme.
///
/// ✅ Domain-Agnostic:
///   - Default neutral dark palette
///   - Fully configured via ShellThemeConfig
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'shell_theme.dart';

/// Build dark theme data from ShellTheme
ThemeData buildDarkTheme(ShellTheme shellTheme) {
  return shellTheme.toThemeData(ThemeMode.dark);
}
