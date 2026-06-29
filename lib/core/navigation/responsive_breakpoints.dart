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
  static const double mobile = 600.0;
  static const double tablet = 1024.0;

  // ── Named breakpoint ranges ──
  static const double mobileMax = 599.0;
  static const double tabletMin = 600.0;
  static const double tabletMax = 1023.0;
  static const double desktopMin = 1024.0;

  // ── Sidebar dimensions ──
  static const double sidebarExpandedWidth = 260.0;
  static const double sidebarCollapsedWidth = 72.0;

  // ── Content width limits ──
  static const double contentMaxWidth = 1200.0;

  // ── Helper helpers ──

  /// Returns true if width is mobile (< 600px)
  static bool isMobile(double width) => width < mobile;

  /// Returns true if width is tablet (600px - 1024px)
  static bool isTablet(double width) => width >= mobile && width < tablet;

  /// Returns true if width is desktop (>= 1024px)
  static bool isDesktop(double width) => width >= tablet;

  /// Returns human-readable label for the current width
  static String labelFor(double width) {
    if (width < mobile) return 'mobile';
    if (width < tablet) return 'tablet';
    return 'desktop';
  }
}
