import 'package:famhub_app/core/dashboard_engine/domain/prediction/predicted_state.dart';

class PredictivePatchCache {
  final Map<String, Map<String, dynamic>> _cache = {};

  void store(PredictedState state) {
    _cache[state.entityId] = state.predictedData;
  }

  Map<String, dynamic>? get(String entityId) {
    return _cache[entityId];
  }

  void invalidate(String entityId) {
    _cache.remove(entityId);
  }
}
