import 'package:flutter/foundation.dart';

@immutable
class DashboardWidgetUsage {
  final String widgetKey;
  final int openCount;
  final int interactionCount;
  final DateTime lastAccessed;

  const DashboardWidgetUsage({
    required this.widgetKey,
    required this.openCount,
    required this.interactionCount,
    required this.lastAccessed,
  });

  /// ⚡ BASE BEHAVIOR SCORE
  int get baseScore =>
      (openCount * 2) + (interactionCount * 3);

  /// ⚡ RECENCY SCORE (time decay)
  double get recencyScore {
    final hoursSinceAccess =
        DateTime.now().difference(lastAccessed).inHours;

    if (hoursSinceAccess < 1) return 1.0;
    if (hoursSinceAccess < 24) return 0.9;
    if (hoursSinceAccess < 72) return 0.7;
    if (hoursSinceAccess < 168) return 0.5; // 7 days
    return 0.2;
  }

  /// ⚡ FINAL SMART SCORE
  double get score => baseScore * recencyScore;
}