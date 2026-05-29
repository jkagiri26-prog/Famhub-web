class WidgetStateModel {
  const WidgetStateModel({
    required this.widgetId,
    required this.state,
    this.lastUpdated,
  });

  final String widgetId;

  /// Generic state bag (form values, scroll, UI state, etc.)
  final Map<String, dynamic> state;

  final DateTime? lastUpdated;

  WidgetStateModel copyWith({
    Map<String, dynamic>? state,
    DateTime? lastUpdated,
  }) {
    return WidgetStateModel(
      widgetId: widgetId,
      state: state ?? this.state,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}