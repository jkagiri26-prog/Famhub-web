import 'dart:math';

import 'package:famhub_app/core/dashboard_engine/domain/prediction/predicted_state.dart';

class DegradationScore {
  final double score;
  final double confidence;
  final Map<String, double> contributingFactors;
  final DegradationTrend trend;

  const DegradationScore({
    required this.score,
    required this.confidence,
    required this.contributingFactors,
    required this.trend,
  });

  String get label {
    if (score < 0.3) return 'healthy';
    if (score < 0.5) return 'watch';
    if (score < 0.7) return 'warning';
    if (score < 0.9) return 'degraded';
    return 'critical';
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'confidence': confidence,
        'label': label,
        'trend': trend.name,
        'factors': contributingFactors,
      };
}

enum DegradationTrend { improving, stable, worsening, volatile }

class DependencyImpact {
  final String dependentModuleId;
  final double impactScore;
  final String impactType;
  const DependencyImpact({
    required this.dependentModuleId,
    required this.impactScore,
    required this.impactType,
  });
  Map<String, dynamic> toJson() => {
        'dependentModuleId': dependentModuleId,
        'impactScore': impactScore,
        'impactType': impactType,
      };
}

class PredictiveEngine {
  final Map<String, List<Map<String, dynamic>>> _historySeries = {};
  final Map<String, List<double>> _metricSeries = {};
  static const int _maxHistoryPoints = 20;

  void record(String entityId, Map<String, dynamic> state) {
    _historySeries.putIfAbsent(entityId, () => []);
    _historySeries[entityId]!.add(state);
    if (_historySeries[entityId]!.length > _maxHistoryPoints) {
      _historySeries[entityId]!.removeAt(0);
    }
  }

  void recordMetric(String entityId, double value) {
    _metricSeries.putIfAbsent(entityId, () => []);
    _metricSeries[entityId]!.add(value);
    if (_metricSeries[entityId]!.length > _maxHistoryPoints) {
      _metricSeries[entityId]!.removeAt(0);
    }
  }

  DegradationScore calculateDegradation(String entityId) {
    final factors = <String, double>{};
    final metrics = _metricSeries[entityId] ?? [];
    final history = _historySeries[entityId] ?? [];
    if (metrics.isEmpty && history.isEmpty) {
      return const DegradationScore(score: 0.0, confidence: 0.1, contributingFactors: {'no_data': 0.0}, trend: DegradationTrend.stable);
    }
    if (metrics.length >= 3) {
      final recent = metrics.sublist(metrics.length - 3);
      factors['failure_rate'] = recent.where((v) => v <= 0).length / recent.length;
    } else {
      factors['failure_rate'] = 0.0;
    }
    if (metrics.length >= 4) {
      final recent = metrics.sublist(metrics.length - 4);
      final firstHalf = recent.take(2).reduce((a, b) => a + b) / 2;
      final secondHalf = recent.skip(2).reduce((a, b) => a + b) / 2;
      factors['duration_trend'] = (secondHalf > firstHalf ? (secondHalf - firstHalf) / firstHalf : 0.0).clamp(0.0, 1.0);
    } else {
      factors['duration_trend'] = 0.0;
    }
    if (metrics.length >= 3) {
      final mean = metrics.reduce((a, b) => a + b) / metrics.length;
      final variance = metrics.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / metrics.length;
      factors['volatility'] = min(1.0, sqrt(variance) / (mean + 0.001));
    } else {
      factors['volatility'] = 0.0;
    }
    const weights = <String, double>{'failure_rate': 0.4, 'duration_trend': 0.35, 'volatility': 0.25};
    double weightedScore = 0;
    for (final entry in factors.entries) {
      weightedScore += entry.value * (weights[entry.key] ?? 0.2);
    }
    return DegradationScore(
      score: weightedScore.clamp(0.0, 1.0),
      confidence: min(1.0, (metrics.length + history.length) / _maxHistoryPoints),
      contributingFactors: factors,
      trend: _assessTrend(entityId),
    );
  }

  List<DependencyImpact> analyzeDependencyImpact({
    required String moduleId,
    required List<String> dependents,
    required double degradationScore,
  }) {
    return dependents.map((depId) {
      final depMetrics = _metricSeries[depId] ?? [];
      double couplingFactor = 0.5;
      if (depMetrics.length >= 3 && _metricSeries[moduleId] != null) {
        final moduleRecent = _metricSeries[moduleId]!.takeLast(3);
        final depRecent = depMetrics.takeLast(3);
        if (moduleRecent.length == depRecent.length && moduleRecent.length >= 2) {
          final corr = _simpleCorrelation(moduleRecent.toList(), depRecent.toList());
          couplingFactor = (corr.abs() * 0.5 + 0.3).clamp(0.3, 0.9);
        }
      }
      final impactScore = degradationScore * couplingFactor;
      return DependencyImpact(
        dependentModuleId: depId,
        impactScore: impactScore.clamp(0.0, 1.0),
        impactType: impactScore > 0.7 ? 'critical' : impactScore > 0.4 ? 'moderate' : 'minor',
      );
    }).toList();
  }

  PredictedState predict(String entityId) {
    final history = _historySeries[entityId];
    if (history == null || history.isEmpty) {
      return PredictedState(entityId: entityId, predictedData: {}, confidence: 0.0, generatedAt: DateTime.now());
    }
    final current = history.last;
    final degradation = calculateDegradation(entityId);
    final predicted = Map<String, dynamic>.from(current);
    predicted['__predicted'] = true;
    predicted['__predictionGeneratedAt'] = DateTime.now().toIso8601String();
    predicted['__degradationScore'] = degradation.score;
    predicted['__degradationLabel'] = degradation.label;
    predicted['__trend'] = degradation.trend.name;
    predicted['__confidence'] = degradation.confidence;
    final metrics = _metricSeries[entityId];
    if (metrics != null && metrics.length >= 3) {
      final recent = metrics.sublist(metrics.length - 3);
      predicted['__predictedNextValue'] = recent.reduce((a, b) => a + b) / recent.length;
    }
    return PredictedState(entityId: entityId, predictedData: predicted, confidence: degradation.confidence, generatedAt: DateTime.now());
  }

  DegradationTrend _assessTrend(String entityId) {
    final metrics = _metricSeries[entityId];
    if (metrics == null || metrics.length < 3) return DegradationTrend.stable;
    final recent = metrics.sublist(metrics.length - 3);
    final diff = recent.last - recent.first;
    if (diff.abs() < 0.05) return DegradationTrend.stable;
    return diff > 0 ? DegradationTrend.worsening : DegradationTrend.improving;
  }

  double _simpleCorrelation(List<double> a, List<double> b) {
    if (a.length != b.length || a.length < 2) return 0;
    final n = a.length;
    final meanA = a.reduce((x, y) => x + y) / n;
    final meanB = b.reduce((x, y) => x + y) / n;
    double cov = 0, varA = 0, varB = 0;
    for (int i = 0; i < n; i++) {
      final da = a[i] - meanA;
      final db = b[i] - meanB;
      cov += da * db;
      varA += da * da;
      varB += db * db;
    }
    final denom = sqrt(varA * varB);
    return denom == 0 ? 0 : cov / denom;
  }
}

extension _ListExtension<T> on List<T> {
  List<T> takeLast(int n) {
    if (n >= length) return List.from(this);
    return sublist(length - n);
  }
}
