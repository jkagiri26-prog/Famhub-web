/// ============================================================
/// RESPONSIVE BREAKPOINT SYSTEM
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Define responsive breakpoint constants
///   - Provide helper methods for breakpoint detection
///
/// ❌ Does NOT:
///   - Reference registries, services, or providers
///   - Contain business logic
///   - Import Flutter widgets
/// ============================================================
class ResponsiveBreakpoints {
  // ── Breakpoint thresholds ──
  static const double compactXs = 360.0;
  static const double mobile = 600.0;
  static const double tablet = 1024.0;
  static const double desktop = 1440.0;

  // ── Named breakpoint ranges ──
  static const double compactXsMax = 359.0;
  static const double mobileMin = 360.0;
  static const double mobileMax = 599.0;
  static const double tabletMin = 600.0;
  static const double tabletMax = 1023.0;
  static const double desktopMin = 1024.0;
  static const double desktopMax = 1439.0;
  static const double ultraWideMin = 1440.0;

  // ── Sidebar dimensions ──
  static const double sidebarExpandedWidth = 260.0;
  static const double sidebarCollapsedWidth = 72.0;

  // ── Content width limits ──
  static const double contentMaxWidth = 1200.0;

  // ── Helper helpers ──

  /// Returns true if width is compact XS (< 360px)
  static bool isCompactXs(double width) => width < compactXs;

  /// Returns true if width is mobile (360px - 599px)
  static bool isMobile(double width) => width >= compactXs && width < mobile;

  /// Returns true if width is tablet (600px - 1024px)
  static bool isTablet(double width) => width >= mobile && width < tablet;

  /// Returns true if width is desktop (1024px - 1439px)
  static bool isDesktop(double width) => width >= tablet && width < desktop;

  /// Returns true if width is ultra-wide (>= 1440px)
  static bool isUltraWide(double width) => width >= desktop;

  /// Returns true if width is any desktop (>= 1024px)
  static bool isDesktopOrWider(double width) => width >= tablet;

  /// Returns human-readable label for the current width
  static String labelFor(double width) {
    if (width < compactXs) return 'compactXs';
    if (width < mobile) return 'mobile';
    if (width < tablet) return 'tablet';
    if (width < desktop) return 'desktop';
    return 'ultraWide';
  }
}

