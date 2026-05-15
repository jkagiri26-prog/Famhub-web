enum FarmWidgetType {
  summary,
  activity,
  production,
  chart,
  list,
  custom,
}

class FarmWidgetDescriptor {
  final String id;
  final FarmWidgetType type;

  /// Optional config payload for widget customization
  final Map<String, dynamic> config;

  /// Feature gating support
  final bool enabled;

  /// Ordering in dashboard
  final int order;

  const FarmWidgetDescriptor({
    required this.id,
    required this.type,
    this.config = const {},
    this.enabled = true,
    this.order = 0,
  });
}