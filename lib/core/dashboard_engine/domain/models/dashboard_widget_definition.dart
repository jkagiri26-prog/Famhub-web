/// ============================================================
/// DASHBOARD WIDGET DEFINITION (DOMAIN CORE)
/// ============================================================
///
/// Pure data model for a dashboard widget defined by backend metadata.
/// Every widget in the dashboard originates from this definition.
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/domain/models/ = domain models
///
/// ✅ Responsibilities:
///   - Pure data model for widget metadata
///   - Defines widget dimensions, behavior, and placement
///
/// ❌ Does NOT:
///   - Contain UI logic
///   - Reference widget builders
///   - Import Flutter widgets
/// ============================================================
class DashboardWidgetDefinition {
  /// Unique widget key for registry lookup
  final String widgetKey;

  /// Owning module identifier
  final String moduleKey;

  /// Section this widget belongs to
  final String sectionKey;

  /// Display name
  final String displayName;

  /// Display order within section
  final int displayOrder;

  /// Widget width in grid units (1-6)
  final int width;

  /// Widget height in grid units (1-6)
  final int height;

  /// Priority for layout placement (higher = more prominent)
  final int priority;

  /// Whether this widget is visible
  final bool isVisible;

  /// Refresh interval in seconds (0 = no auto-refresh)
  final int refreshIntervalSeconds;

  /// Minimum role level required
  final String? requiredRole;

  /// Whether widget appears on mobile
  final bool showOnMobile;

  /// Whether widget appears on tablet
  final bool showOnTablet;

  /// Whether widget appears on desktop
  final bool showOnDesktop;

  /// Icon key for widget header
  final String iconKey;

  /// Whether widget requires a subscription
  final bool requiresSubscription;

  /// Whether widget requires an entity (farm/business)
  final bool requiresEntity;

  const DashboardWidgetDefinition({
    required this.widgetKey,
    required this.moduleKey,
    required this.sectionKey,
    required this.displayName,
    this.displayOrder = 0,
    this.width = 1,
    this.height = 1,
    this.priority = 0,
    this.isVisible = true,
    this.refreshIntervalSeconds = 0,
    this.requiredRole,
    this.showOnMobile = true,
    this.showOnTablet = true,
    this.showOnDesktop = true,
    this.iconKey = 'widgets',
    this.requiresSubscription = false,
    this.requiresEntity = false,
  });

  factory DashboardWidgetDefinition.fromMap(Map<String, dynamic> map) {
    return DashboardWidgetDefinition(
      widgetKey: map['widget_key']?.toString() ?? '',
      moduleKey: map['module_key']?.toString() ?? '',
      sectionKey: map['section_key']?.toString() ?? 'default',
      displayName: map['display_name']?.toString() ?? 'Widget',
      displayOrder: map['display_order'] ?? 0,
      width: map['width'] ?? 1,
      height: map['height'] ?? 1,
      priority: map['priority'] ?? 0,
      isVisible: map['is_visible'] ?? true,
      refreshIntervalSeconds: map['refresh_interval_seconds'] ?? 0,
      requiredRole: map['required_role']?.toString(),
      showOnMobile: map['show_on_mobile'] ?? true,
      showOnTablet: map['show_on_tablet'] ?? true,
      showOnDesktop: map['show_on_desktop'] ?? true,
      iconKey: map['icon_key']?.toString() ?? 'widgets',
      requiresSubscription: map['requires_subscription'] ?? false,
      requiresEntity: map['requires_entity'] ?? false,
    );
  }

  /// Whether this widget can be shown on a given device type.
  /// Treats 'compactXs' as 'mobile' and 'ultraWide' as 'desktop'.
  bool isVisibleOnDevice(String deviceType) {
    switch (deviceType) {
      case 'compactXs':
      case 'mobile':
        return showOnMobile;
      case 'tablet':
        return showOnTablet;
      case 'ultraWide':
      case 'desktop':
        return showOnDesktop;
      default:
        return true;
    }
  }

  @override
  String toString() =>
      'DashboardWidgetDefinition($widgetKey: $displayName)';
}
