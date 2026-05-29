class PredictedState {
  const PredictedState({
    required this.entityId,
    required this.predictedData,
    required this.confidence,
    required this.generatedAt,
  });

  final String entityId;

  /// predicted next state snapshot
  final Map<String, dynamic> predictedData;

  /// 0.0 → 1.0 confidence score
  final double confidence;

  final DateTime generatedAt;
}