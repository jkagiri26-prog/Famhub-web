/// ============================================================
/// FARM WIDGET DESCRIPTOR
/// ============================================================
///
/// Describes a dashboard widget for the farm management feature.
/// Used by the dashboard descriptor provider to compose the
/// farm dashboard layout.
/// ============================================================
library;

/// The type of a farm dashboard widget.
enum FarmWidgetType {
  /// Summary / overview widget
  summary,

  /// Activity feed widget
  activity,

  /// Production summary widget
  production,

  /// Stock / inventory widget
  stock,

  /// Livestock overview widget
  livestock,

  /// Alert widget
  alerts,

  /// Weather widget
  weather,

  /// Health indicator widget
  health,
}

/// Descriptor for a farm dashboard widget.
class FarmWidgetDescriptor {
  final String id;
  final FarmWidgetType type;
  final int order;
  final String? title;
  final double? width;
  final double? height;

  const FarmWidgetDescriptor({
    required this.id,
    required this.type,
    required this.order,
    this.title,
    this.width,
    this.height,
  });

  String get displayName {
    switch (type) {
      case FarmWidgetType.summary:
        return 'Farm Summary';
      case FarmWidgetType.activity:
        return 'Activity Timeline';
      case FarmWidgetType.production:
        return 'Production Summary';
      case FarmWidgetType.stock:
        return 'Stock Summary';
      case FarmWidgetType.livestock:
        return 'Livestock Overview';
      case FarmWidgetType.alerts:
        return 'Alerts';
      case FarmWidgetType.weather:
        return 'Weather';
      case FarmWidgetType.health:
        return 'Farm Health';
    }
  }
}
