// lib/core/dashboard_engine/domain/models/widget_state_model.dart

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

  /// ============================================================
  /// COPY WITH
  /// ============================================================
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

  /// ============================================================
  /// VALUE EQUALITY (IMPORTANT FOR DIFFING + CACHE)
  /// ============================================================
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WidgetStateModel &&
        other.widgetId == widgetId &&
        _mapEquals(other.state, state) &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode =>
      widgetId.hashCode ^ state.hashCode ^ lastUpdated.hashCode;

  /// ============================================================
  /// DEBUG
  /// ============================================================
  @override
  String toString() =>
      'WidgetStateModel(widgetId: $widgetId, state: $state, lastUpdated: $lastUpdated)';

  /// ============================================================
  /// INTERNAL MAP COMPARISON
  /// ============================================================
  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}