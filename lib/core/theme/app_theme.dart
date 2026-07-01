/// ============================================================
/// APP THEME — Application-wide theme configuration
/// ============================================================
///
/// 🎯 PURPOSE:
///   Central entry point for theme configuration.
///   Delegates to ShellTheme for the shell layer and
///   allows domain modules to extend with their own theme data.
///
/// ✅ Domain-Agnostic:
///   - No agriculture-specific styling
///   - Neutral design language
///   - Brand colors injected via ShellThemeConfig
/// ============================================================
library;

export 'shell_theme.dart';
export 'shell_theme_provider.dart';
export 'light_theme.dart';
export 'dark_theme.dart';
export 'text_styles.dart';
