class WidgetStateStore {
  final Map<String, WidgetStateModel> _store = {};

  /// Get widget state
  WidgetStateModel? get(String widgetId) {
    return _store[widgetId];
  }

  /// Save or update widget state
  void upsert(WidgetStateModel model) {
    _store[model.widgetId] = model.copyWith(
      lastUpdated: DateTime.now(),
    );
  }

  /// Update partial state
  void updateState(
    String widgetId,
    Map<String, dynamic> patch,
  ) {
    final existing = _store[widgetId];

    if (existing == null) {
      _store[widgetId] = WidgetStateModel(
        widgetId: widgetId,
        state: patch,
        lastUpdated: DateTime.now(),
      );
      return;
    }

    _store[widgetId] = existing.copyWith(
      state: {
        ...existing.state,
        ...patch,
      },
      lastUpdated: DateTime.now(),
    );
  }

  /// Remove widget state
  void remove(String widgetId) {
    _store.remove(widgetId);
  }

  /// Clear all (rare use)
  void clear() {
    _store.clear();
  }
}