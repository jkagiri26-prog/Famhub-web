class DashboardWidgetLayout {
  final String moduleKey;
  final String widgetId;
  final String featureKey;
  final int order;
  final int flex;
  final bool isVisible;

  const DashboardWidgetLayout({
    required this.moduleKey,
    required this.widgetId,
    required this.featureKey,
    required this.order,
    required this.flex,
    required this.isVisible,
  });

  factory DashboardWidgetLayout.fromMap(Map<String, dynamic> map) {
    return DashboardWidgetLayout(
      moduleKey: map['module_key'],
      widgetId: map['widget_id'],
      featureKey: map['feature_key'],
      order: map['display_order'] ?? 0,
      flex: map['flex'] ?? 1,
      isVisible: map['is_visible'] ?? true,
    );
  }
}