/// ============================================================
/// LIGHT THEME — Light mode theme configuration
/// ============================================================
///
/// 🎯 PURPOSE:
///   Provides light mode ThemeData using ShellTheme.
///   No hardcoded colors — everything comes from ShellTheme.
///
/// ✅ Domain-Agnostic:
///   - Default neutral palette
///   - Fully configured via ShellThemeConfig
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'shell_theme.dart';

/// Build light theme data from ShellTheme
ThemeData buildLightTheme(ShellTheme shellTheme) {
  return shellTheme.toThemeData(ThemeMode.light);
}
