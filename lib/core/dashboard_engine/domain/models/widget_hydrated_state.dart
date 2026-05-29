class WidgetHydratedState {
  const WidgetHydratedState({
    required this.widgetId,
    required this.state,
    required this.updatedAt,
  });

  final String widgetId;
  final Map<String, dynamic> state;
  final DateTime updatedAt;
}