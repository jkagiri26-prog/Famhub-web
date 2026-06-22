// ignore: dangling_library_doc_comments
/// ============================================================
/// OPERATIONAL DASHBOARD PROVIDER — PHASE 3
/// ============================================================
///
/// PURPOSE:
/// Aggregates all runtime observability data into a single
/// operational dashboard model for admin and developer use.
///
/// RESPONSIBILITIES:
/// - Aggregate health, metrics, resilience, degradation, modules
/// - Provide a unified dashboard model
/// - Support filtering and drill-down
///
/// NON-RESPONSIBILITIES:
/// - UI rendering (used by display widgets)
/// - Replacing existing individual providers
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/presentation/providers/ = presentation layer
///
/// ✅ USAGE:
/// ```dart
/// final dashboard = ref.watch(operationalDashboardProvider);
/// print(dashboard.overallHealth);
/// print(dashboard.unhealthyModules);
/// ```
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/providers/observability_providers.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/provider_health_monitor.dart';
import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';

/// ============================================================
/// OPERATIONAL DASHBOARD MODEL
/// ============================================================
class OperationalDashboard {
  final RuntimeHealthStatus overallHealth;
  final int totalModules;
  final int healthyModules;
  final int degradedModules;
  final int unhealthyModules;
  final int totalEvents;
  final double eventsPerSecond;
  final int failures;
  final int recoveries;
  final double recoveryRate;
  final int slowModuleCount;
  final List<String> slowestModuleIds;
  final Duration uptime;
  final double averagePatchDurationMs;
  final double p95PatchDurationMs;
  final int currentStreak;
  final int consecutiveFailures;
  final bool providerGraphHealthy;
  final List<ProviderHealthEntry> unhealthyProviders;
  final int analyticsWindowCount;
  final DateTime snapshotAt;

  const OperationalDashboard({
    required this.overallHealth,
    required this.totalModules,
    required this.healthyModules,
    required this.degradedModules,
    required this.unhealthyModules,
    required this.totalEvents,
    required this.eventsPerSecond,
    required this.failures,
    required this.recoveries,
    required this.recoveryRate,
    required this.slowModuleCount,
    required this.slowestModuleIds,
    required this.uptime,
    required this.averagePatchDurationMs,
    required this.p95PatchDurationMs,
    required this.currentStreak,
    required this.consecutiveFailures,
    required this.providerGraphHealthy,
    required this.unhealthyProviders,
    required this.analyticsWindowCount,
    required this.snapshotAt,
  });

  /// Human-readable health label
  String get healthLabel {
    switch (overallHealth) {
      case RuntimeHealthStatus.healthy:
        return 'All Systems Operational';
      case RuntimeHealthStatus.degraded:
        return 'Degraded Performance';
      case RuntimeHealthStatus.corrupted:
        return 'Critical Issues Detected';
      case RuntimeHealthStatus.recovering:
        return 'System Recovering';
      case RuntimeHealthStatus.replaying:
        return 'Event Replay Active';
      case RuntimeHealthStatus.overflow:
        return 'Buffer Overflow Risk';
    }
  }

  /// Whether critical attention is needed
  bool get needsAttention =>
      overallHealth != RuntimeHealthStatus.healthy ||
      unhealthyModules > 0 ||
      !providerGraphHealthy;

  Map<String, dynamic> toJson() => {
        'overallHealth': overallHealth.name,
        'healthLabel': healthLabel,
        'totalModules': totalModules,
        'healthyModules': healthyModules,
        'degradedModules': degradedModules,
        'criticalModules': unhealthyModules,
        'totalEvents': totalEvents,
        'eventsPerSecond': eventsPerSecond,
        'failures': failures,
        'recoveries': recoveries,
        'recoveryRate': recoveryRate,
        'slowModuleCount': slowModuleCount,
        'uptimeMs': uptime.inMilliseconds,
        'averagePatchDurationMs': averagePatchDurationMs,
        'p95PatchDurationMs': p95PatchDurationMs,
        'currentStreak': currentStreak,
        'consecutiveFailures': consecutiveFailures,
        'providerGraphHealthy': providerGraphHealthy,
        'analyticsWindowCount': analyticsWindowCount,
        'snapshotAt': snapshotAt.toIso8601String(),
      };
}

/// ============================================================
/// OPERATIONAL DASHBOARD PROVIDER
/// ============================================================
final operationalDashboardProvider = Provider<OperationalDashboard>((ref) {
  final analytics = ref.watch(runtimeAnalyticsProvider);
  final snapshot = ref.watch(latestHealthSnapshotProvider);
  final moduleMetrics = ref.watch(moduleMetricsProvider);
  final providerHealth = ref.watch(providerHealthSnapshotProvider);
  final resilience = ref.watch(resilienceMetricsProvider);

  // Count module health states
  int healthyCount = 0, degradedCount = 0, unhealthyCount = 0;
  final List<String> slowestIds = [];

  for (final m in moduleMetrics.entries) {
    if (m.value.healthIndex >= 0.8) {
      healthyCount++;
    } else if (m.value.healthIndex >= 0.5) {
      degradedCount++;
    } else {
      unhealthyCount++;
      slowestIds.add(m.key);
    }
  }

  // Build slowest module list from snapshot
  final slowestModules = snapshot?.slowestModules ?? [];
  for (final slow in slowestModules) {
    if (!slowestIds.contains(slow.moduleId)) {
      slowestIds.add(slow.moduleId);
    }
  }

  return OperationalDashboard(
    overallHealth: analytics.healthStatus,
    totalModules: moduleMetrics.length,
    healthyModules: healthyCount,
    degradedModules: degradedCount,
    unhealthyModules: unhealthyCount,
    totalEvents: analytics.totalEvents,
    eventsPerSecond: analytics.eventsPerSecond,
    failures: analytics.failures,
    recoveries: analytics.recoveries,
    recoveryRate: analytics.recoveryRate,
    slowModuleCount: slowestIds.length,
    slowestModuleIds: slowestIds.take(10).toList(),
    uptime: analytics.uptime,
    averagePatchDurationMs: analytics.averagePatchDurationMs,
    p95PatchDurationMs: analytics.p95PatchDurationMs,
    currentStreak: resilience.currentStreak,
    consecutiveFailures: resilience.consecutiveFailures,
    providerGraphHealthy: providerHealth.allHealthy,
    unhealthyProviders: providerHealth.unhealthyProviders,
    analyticsWindowCount: analytics.analyticsWindows.length,
    snapshotAt: DateTime.now(),
  );
});
