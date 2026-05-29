import '../../domain/prediction/predicted_state.dart';

class PredictiveEngine {
  final Map<String, Map<String, dynamic>> _history = {};

  /// ============================================================
  /// RECORD STATE HISTORY
  /// ============================================================
  void record(String entityId, Map<String, dynamic> state) {
    _history[entityId] = state;
  }

  /// ============================================================
  /// PREDICT NEXT STATE (SIMPLE HEURISTIC VERSION)
  /// ============================================================
  PredictedState predict(String entityId) {
    final current = _history[entityId];

    if (current == null) {
      return PredictedState(
        entityId: entityId,
        predictedData: {},
        confidence: 0.0,
        generatedAt: DateTime.now(),
      );
    }

    /// Simple heuristic:
    /// (future upgrade: ML or sequence model)
    final predicted = Map<String, dynamic>.from(current);

    predicted['__predicted'] = true;
    predicted['lastUpdated'] = DateTime.now().toIso8601String();

    return PredictedState(
      entityId: entityId,
      predictedData: predicted,
      confidence: 0.6,
      generatedAt: DateTime.now(),
    );
  }
}