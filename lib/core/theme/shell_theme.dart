/// ============================================================
/// SHELL THEME — Domain-agnostic theme configuration model
/// ============================================================
/// SHELL THEME — Domain-agnostic theme configuration model
/// ============================================================
///
/// 🎯 PURPOSE:
///   Replace all hardcoded colors and agriculture-specific styling
///   with a neutral, configurable theme system. The shell never
///   hardcodes brand colors — it consumes them from this model.
///
/// ✅ Design Principles:
///   - Domain-agnostic (no agriculture-specific colors/icons)
///   - Neutral design language inspired by modern productivity platforms
///   - Default palette defined, but fully overridable
///   - Supports light AND dark themes from the same model
///   - Consumed by UnifiedAppShell and all its components
///
/// 🎨 Default Shell Palette:
///   Background:  #F8FAFC  (slate-50)
///   Surface:     #FFFFFF
///   Border:      #E5E7EB  (gray-200)
///   Primary Text:#111827  (gray-900)
///   Secondary Txt:#6B7280 (gray-500)
///   Hover:       #F3F4F6  (gray-100)
///
/// 🏢 Usage in any domain:
///   - FAMHUB:    Brand colors injected via ShellThemeData
///   - FactoryERP: Brand colors injected via ShellThemeData
///   - SocialNet:  Brand colors injected via ShellThemeData
///   - Healthcare: Brand colors injected via ShellThemeData
///   - Finance:    Brand colors injected via ShellThemeData
/// ============================================================
library;

import 'package:flutter/material.dart';

/// ============================================================
/// SHELL THEME DATA — Complete theme for the shell
/// ============================================================
///
/// This is the SINGLE configuration object that defines the
/// entire visual language of the shell. No hardcoded colors
/// anywhere in the shell widgets — everything comes from here.
///
/// [light] — Light mode colors
/// [dark]  — Dark mode colors
/// [brand] — Brand identity (logo, name, tagline)
/// [assets] — Custom asset paths (logos, icons)
/// [typography] — Font family overrides
/// ============================================================
class ShellTheme {
  final ShellColorPalette light;
  final ShellColorPalette dark;
  final ShellBrand brand;
  final ShellAssets assets;
  final ShellTypography typography;

  const ShellTheme({
    required this.light,
    required this.dark,
    this.brand = const ShellBrand(),
    this.assets = const ShellAssets(),
    this.typography = const ShellTypography(),
  });

  /// ============================================================
  /// DEFAULT — Neutral, domain-agnostic palette
  /// ============================================================
  /// Spec-accurate light palette
  /// Background:   #F8FAFC
  /// Surface:      #FFFFFF
  /// Border:       #E5E7EB
  /// Primary Text: #111827
  /// Secondary:    #6B7280
  /// Hover:        #F3F4F6
  /// Disabled:     #D1D5DB
  /// Success:      #16A34A
  /// Warning:      #D97706
  /// Error:        #DC2626
  /// Info:         #2563EB
  static const defaultLight = ShellColorPalette(
    name: 'Default Light',
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F5F9),
    border: Color(0xFFE5E7EB),
    borderFocused: Color(0xFF6366F1),
    primary: Color(0xFF6366F1),
    primaryText: Color(0xFF111827),
    secondaryText: Color(0xFF6B7280),
    tertiaryText: Color(0xFF9CA3AF),
    disabled: Color(0xFFD1D5DB),
    hover: Color(0xFFF3F4F6),
    divider: Color(0xFFE5E7EB),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
    successBg: Color(0xFFECFDF5),
    warningBg: Color(0xFFFFFBEB),
    errorBg: Color(0xFFFEF2F2),
    infoBg: Color(0xFFEFF6FF),
    shadow: Color(0x08000000),
    overlay: Color(0x40000000),
    navigationBg: Color(0xFFFFFFFF),
    navigationHover: Color(0xFFF3F4F6),
    navigationSelectedBg: Color(0x0D6366F1),
    navigationSelectedText: Color(0xFF6366F1),
    statusBarBg: Color(0xFFF8FAFC),
    statusBarText: Color(0xFF6B7280),
  );

  /// Spec-accurate dark palette
  /// Background:   #0F172A
  /// Surface:      #1E293B
  /// Border:       #334155
  /// Primary Text: #F8FAFC
  /// Secondary:    #CBD5E1
  /// Hover:        #334155
  /// Disabled:     #64748B
  /// Success:      #22C55E
  /// Warning:      #F59E0B
  /// Error:        #EF4444
  /// Info:         #3B82F6
  static const defaultDark = ShellColorPalette(
    name: 'Default Dark',
    background: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceVariant: Color(0xFF334155),
    border: Color(0xFF334155),
    borderFocused: Color(0xFF818CF8),
    primary: Color(0xFF818CF8),
    primaryText: Color(0xFFF8FAFC),
    secondaryText: Color(0xFFCBD5E1),
    tertiaryText: Color(0xFF64748B),
    disabled: Color(0xFF64748B),
    hover: Color(0xFF334155),
    divider: Color(0xFF334155),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    successBg: Color(0xFF064E3B),
    warningBg: Color(0xFF451A03),
    errorBg: Color(0xFF7F1D1D),
    infoBg: Color(0xFF1E3A5F),
    shadow: Color(0x20000000),
    overlay: Color(0x60000000),
    navigationBg: Color(0xFF1E293B),
    navigationHover: Color(0xFF334155),
    navigationSelectedBg: Color(0x14818CF8),
    navigationSelectedText: Color(0xFF818CF8),
    statusBarBg: Color(0xFF0F172A),
    statusBarText: Color(0xFF94A3B8),
  );

  /// ============================================================
  /// FACTORY — Create from brand colors
  /// ============================================================
  ///
  /// Given a brand primary color, generates a complete light+dark
  /// palette that harmonizes with the brand while maintaining
  /// neutral design principles.
  ///
  /// Example:
  /// ```dart
  /// final theme = ShellTheme.fromBrand(
  ///   brandPrimary: Color(0xFF059669),  // FAMHUB green
  ///   brandName: 'FAMHUB',
  /// );
  /// ```
  /// ============================================================
  factory ShellTheme.fromBrand({
    required Color brandPrimary,
    String brandName = 'App',
    String? brandTagline,
    String? logoAsset,
    String? iconAsset,
    bool isDark = false,
  }) {
    return ShellTheme(
      light: defaultLight.copyWith(
        primary: brandPrimary,
        navigationSelectedBg: brandPrimary.withValues(alpha: 0.08),
        navigationSelectedText: brandPrimary,
        borderFocused: brandPrimary,
      ),
      dark: defaultDark.copyWith(
        primary: brandPrimary,
        navigationSelectedBg: brandPrimary.withValues(alpha: 0.12),
        navigationSelectedText: brandPrimary,
        borderFocused: brandPrimary,
      ),
      brand: ShellBrand(
        name: brandName,
        tagline: brandTagline,
      ),
      assets: ShellAssets(
        logoAsset: logoAsset,
        iconAsset: iconAsset,
      ),
    );
  }

  /// Get the palette for the current theme mode
  ShellColorPalette forMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return light;
      case ThemeMode.dark:
        return dark;
      case ThemeMode.system:
        // WidgetsBinding is not available here; caller should resolve
        return light;
    }
  }

  /// Generate Flutter ThemeData from shell theme
  ThemeData toThemeData(ThemeMode mode, {Brightness? brightness}) {
    final palette = mode == ThemeMode.dark ? dark : light;
    final isDark = mode == ThemeMode.dark || brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: palette.primary,
      onPrimary: palette.surface,
      secondary: palette.primary,
      onSecondary: palette.surface,
      tertiary: palette.info,
      onTertiary: palette.surface,
      error: palette.error,
      onError: palette.surface,
      surface: palette.surface,
      onSurface: palette.primaryText,
      surfaceContainerHighest: palette.surfaceVariant,
      onSurfaceVariant: palette.secondaryText,
      outline: palette.border,
      outlineVariant: palette.divider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          color: palette.primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.navigationSelectedBg,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: palette.navigationSelectedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: palette.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: palette.navigationSelectedText,
              size: 22,
            );
          }
          return IconThemeData(
            color: palette.secondaryText,
            size: 22,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceVariant,
        labelStyle: TextStyle(color: palette.primaryText),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.borderFocused, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: palette.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(color: palette.primaryText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? palette.surface : palette.primaryText,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: isDark ? palette.primaryText : palette.surface,
          fontSize: 12,
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: palette.error,
        textColor: Colors.white,
        smallSize: 6,
        largeSize: 16,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: palette.border),
            ),
          ),
        ),
      ),
      extensions: [
        ShellThemeColors(palette),
      ],
    );
  }
}

/// ============================================================
/// SHELL COLOR PALETTE — All colors used by the shell
/// ============================================================
class ShellColorPalette {
  final String name;

  // ── Core surfaces ──
  final Color background;
  final Color surface;
  final Color surfaceVariant;

  // ── Borders ──
  final Color border;
  final Color borderFocused;

  // ── Brand ──
  final Color primary;

  // ── Text ──
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;

  // ── Interaction ──
  final Color disabled;
  final Color hover;
  final Color divider;

  // ── Semantic ──
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // ── Semantic backgrounds ──
  final Color successBg;
  final Color warningBg;
  final Color errorBg;
  final Color infoBg;

  // ── Effects ──
  final Color shadow;
  final Color overlay;

  // ── Navigation specific ──
  final Color navigationBg;
  final Color navigationHover;
  final Color navigationSelectedBg;
  final Color navigationSelectedText;

  // ── Status bar ──
  final Color statusBarBg;
  final Color statusBarText;

  const ShellColorPalette({
    required this.name,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.borderFocused,
    required this.primary,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.disabled,
    required this.hover,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.successBg,
    required this.warningBg,
    required this.errorBg,
    required this.infoBg,
    required this.shadow,
    required this.overlay,
    required this.navigationBg,
    required this.navigationHover,
    required this.navigationSelectedBg,
    required this.navigationSelectedText,
    required this.statusBarBg,
    required this.statusBarText,
  });

  ShellColorPalette copyWith({
    String? name,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? borderFocused,
    Color? primary,
    Color? primaryText,
    Color? secondaryText,
    Color? tertiaryText,
    Color? disabled,
    Color? hover,
    Color? divider,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? successBg,
    Color? warningBg,
    Color? errorBg,
    Color? infoBg,
    Color? shadow,
    Color? overlay,
    Color? navigationBg,
    Color? navigationHover,
    Color? navigationSelectedBg,
    Color? navigationSelectedText,
    Color? statusBarBg,
    Color? statusBarText,
  }) {
    return ShellColorPalette(
      name: name ?? this.name,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      border: border ?? this.border,
      borderFocused: borderFocused ?? this.borderFocused,
      primary: primary ?? this.primary,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      disabled: disabled ?? this.disabled,
      hover: hover ?? this.hover,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      successBg: successBg ?? this.successBg,
      warningBg: warningBg ?? this.warningBg,
      errorBg: errorBg ?? this.errorBg,
      infoBg: infoBg ?? this.infoBg,
      shadow: shadow ?? this.shadow,
      overlay: overlay ?? this.overlay,
      navigationBg: navigationBg ?? this.navigationBg,
      navigationHover: navigationHover ?? this.navigationHover,
      navigationSelectedBg: navigationSelectedBg ?? this.navigationSelectedBg,
      navigationSelectedText:
          navigationSelectedText ?? this.navigationSelectedText,
      statusBarBg: statusBarBg ?? this.statusBarBg,
      statusBarText: statusBarText ?? this.statusBarText,
    );
  }
}

/// ============================================================
/// SHELL BRAND — Application brand identity
/// ============================================================
class ShellBrand {
  final String name;
  final String? tagline;

  const ShellBrand({
    this.name = 'App',
    this.tagline,
  });
}

/// ============================================================
/// SHELL ASSETS — Custom asset paths
/// ============================================================
class ShellAssets {
  final String? logoAsset;
  final String? iconAsset;
  final String? faviconAsset;

  const ShellAssets({
    this.logoAsset,
    this.iconAsset,
    this.faviconAsset,
  });
}

/// ============================================================
/// SHELL TYPOGRAPHY — Font customization
/// ============================================================
class ShellTypography {
  final String? fontFamily;
  final String? monospaceFontFamily;

  const ShellTypography({
    this.fontFamily,
    this.monospaceFontFamily,
  });
}

/// ============================================================
/// SHELL THEME COLORS — Theme extension for widgets
/// ============================================================
///
/// Allows any widget to access shell colors via:
/// ```dart
/// final shellColors = Theme.of(context).extension<ShellThemeColors>()!;
/// ```
/// ============================================================
class ShellThemeColors extends ThemeExtension<ShellThemeColors> {
  final ShellColorPalette palette;

  const ShellThemeColors(this.palette);

  @override
  ThemeExtension<ShellThemeColors> copyWith({
    ShellColorPalette? palette,
  }) {
    return ShellThemeColors(palette ?? this.palette);
  }

  @override
  ThemeExtension<ShellThemeColors> lerp(
    covariant ThemeExtension<ShellThemeColors>? other,
    double t,
  ) {
    if (other is! ShellThemeColors) return this;
    return ShellThemeColors(palette);
  }

  // Convenience getters
  Color get background => palette.background;
  Color get surface => palette.surface;
  Color get surfaceVariant => palette.surfaceVariant;
  Color get border => palette.border;
  Color get borderFocused => palette.borderFocused;
  Color get primary => palette.primary;
  Color get primaryText => palette.primaryText;
  Color get secondaryText => palette.secondaryText;
  Color get tertiaryText => palette.tertiaryText;
  Color get hover => palette.hover;
  Color get divider => palette.divider;
  Color get success => palette.success;
  Color get warning => palette.warning;
  Color get error => palette.error;
  Color get info => palette.info;
  Color get navigationBg => palette.navigationBg;
  Color get navigationHover => palette.navigationHover;
  Color get navigationSelectedBg => palette.navigationSelectedBg;
  Color get navigationSelectedText => palette.navigationSelectedText;
  Color get statusBarBg => palette.statusBarBg;
  Color get statusBarText => palette.statusBarText;
}
