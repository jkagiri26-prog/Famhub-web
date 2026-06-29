/// ============================================================
/// CONTRIBUTION OBSERVABILITY (ENTERPRISE PHASE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/observability/ = composition observability
///
/// ✅ Responsibilities:
///   - Extend existing observability with runtime composition metrics
///   - Track: composition duration, contribution count, module init time,
///     failed contributions, permission denials, dependency resolution,
///     dashboard render duration, search/notification provider counts,
///     quick action/route counts, memory usage estimates
///   - Expose metrics for Admin Console
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Extends existing CompositionMetricsCollector
///   - Does NOT replace existing observability
///   - Does NOT import UI or widget trees
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/domain/models/composition_metrics.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';

/// ============================================================
/// CONTRIBUTION METRICS
/// ============================================================
///
/// Tracks metrics specific to the Runtime Contribution Engine.
/// These supplement the existing CompositionMetrics.
/// ============================================================
class ContributionMetrics {
  // ── Timing ──
  final int totalCompositionDurationMs;
  final int dashboardCompositionDurationMs;
  final int homeCompositionDurationMs;
  final int commandPaletteCompositionDurationMs;

  // ── Contribution Counts ──
  final int dashboardWidgetCount;
  final int homeWidgetCount;
  final int quickActionCount;
  final int routeCount;
  final int notificationProviderCount;
  final int searchProviderCount;
  final int analyticsProviderCount;
  final int aiProviderCount;
  final int commandPaletteActionCount;
  final int backgroundJobCount;
  final int fabCount;
  final int settingsPageCount;
  final int reportCount;
  final int exportProviderCount;
  final int importProviderCount;
  final int activityTimelineItemCount;
  final int helpArticleCount;
  final int contextMenuCount;
  final int entityActionCount;
  final int workflowStepCount;
  final int approvalActionCount;

  // ── Module Health ──
  final int modulesWithContributions;
  final int totalModulesProcessed;
  final int failedModuleContributions;
  final int permissionDenials;
  final int dependencyResolutionFailures;

  // ── Memory ──
  final int estimatedMemoryUsageBytes;

  // ── Timestamp ──
  final DateTime recordedAt;

  const ContributionMetrics({
    this.totalCompositionDurationMs = 0,
    this.dashboardCompositionDurationMs = 0,
    this.homeCompositionDurationMs = 0,
    this.commandPaletteCompositionDurationMs = 0,
    this.dashboardWidgetCount = 0,
    this.homeWidgetCount = 0,
    this.quickActionCount = 0,
    this.routeCount = 0,
    this.notificationProviderCount = 0,
    this.searchProviderCount = 0,
    this.analyticsProviderCount = 0,
    this.aiProviderCount = 0,
    this.commandPaletteActionCount = 0,
    this.backgroundJobCount = 0,
    this.fabCount = 0,
    this.settingsPageCount = 0,
    this.reportCount = 0,
    this.exportProviderCount = 0,
    this.importProviderCount = 0,
    this.activityTimelineItemCount = 0,
    this.helpArticleCount = 0,
    this.contextMenuCount = 0,
    this.entityActionCount = 0,
    this.workflowStepCount = 0,
    this.approvalActionCount = 0,
    this.modulesWithContributions = 0,
    this.totalModulesProcessed = 0,
    this.failedModuleContributions = 0,
    this.permissionDenials = 0,
    this.dependencyResolutionFailures = 0,
    this.estimatedMemoryUsageBytes = 0,
    required this.recordedAt,
  });

  /// Total contributions across all types
  int get totalContributions =>
      dashboardWidgetCount +
      homeWidgetCount +
      quickActionCount +
      routeCount +
      notificationProviderCount +
      searchProviderCount +
      analyticsProviderCount +
      aiProviderCount +
      commandPaletteActionCount +
      backgroundJobCount +
      fabCount +
      settingsPageCount +
      reportCount +
      exportProviderCount +
      importProviderCount +
      activityTimelineItemCount +
      helpArticleCount +
      contextMenuCount +
      entityActionCount +
      workflowStepCount +
      approvalActionCount;

  Map<String, dynamic> toJson() => {
        'totalCompositionDurationMs': totalCompositionDurationMs,
        'dashboardCompositionDurationMs': dashboardCompositionDurationMs,
        'homeCompositionDurationMs': homeCompositionDurationMs,
        'commandPaletteCompositionDurationMs': commandPaletteCompositionDurationMs,
        'dashboardWidgetCount': dashboardWidgetCount,
        'homeWidgetCount': homeWidgetCount,
        'quickActionCount': quickActionCount,
        'routeCount': routeCount,
        'notificationProviderCount': notificationProviderCount,
        'searchProviderCount': searchProviderCount,
        'analyticsProviderCount': analyticsProviderCount,
        'aiProviderCount': aiProviderCount,
        'commandPaletteActionCount': commandPaletteActionCount,
        'backgroundJobCount': backgroundJobCount,
        'fabCount': fabCount,
        'settingsPageCount': settingsPageCount,
        'reportCount': reportCount,
        'exportProviderCount': exportProviderCount,
        'importProviderCount': importProviderCount,
        'activityTimelineItemCount': activityTimelineItemCount,
        'helpArticleCount': helpArticleCount,
        'contextMenuCount': contextMenuCount,
        'entityActionCount': entityActionCount,
        'workflowStepCount': workflowStepCount,
        'approvalActionCount': approvalActionCount,
        'totalContributions': totalContributions,
        'modulesWithContributions': modulesWithContributions,
        'totalModulesProcessed': totalModulesProcessed,
        'failedModuleContributions': failedModuleContributions,
        'permissionDenials': permissionDenials,
        'dependencyResolutionFailures': dependencyResolutionFailures,
        'estimatedMemoryUsageBytes': estimatedMemoryUsageBytes,
        'recordedAt': recordedAt.toIso8601String(),
      };
}

/// ============================================================
/// CONTRIBUTION METRICS COLLECTOR
/// ============================================================
///
/// Collects runtime contribution metrics for observability.
/// Reset periodically or when taking a snapshot.
/// ============================================================
class ContributionMetricsCollector {
  // ── Timing ──
  int _totalCompositionDurationMs = 0;
  int _dashboardCompositionDurationMs = 0;
  int _homeCompositionDurationMs = 0;
  int _commandPaletteCompositionDurationMs = 0;

  // ── Contribution Counts ──
  int _dashboardWidgetCount = 0;
  int _homeWidgetCount = 0;
  int _quickActionCount = 0;
  int _routeCount = 0;
  int _notificationProviderCount = 0;
  int _searchProviderCount = 0;
  int _analyticsProviderCount = 0;
  int _aiProviderCount = 0;
  int _commandPaletteActionCount = 0;
  int _backgroundJobCount = 0;
  int _fabCount = 0;
  int _settingsPageCount = 0;
  int _reportCount = 0;
  int _exportProviderCount = 0;
  int _importProviderCount = 0;
  int _activityTimelineItemCount = 0;
  int _helpArticleCount = 0;
  int _contextMenuCount = 0;
  int _entityActionCount = 0;
  int _workflowStepCount = 0;
  int _approvalActionCount = 0;

  // ── Module Health ──
  int _modulesWithContributions = 0;
  int _totalModulesProcessed = 0;
  int _failedModuleContributions = 0;
  int _permissionDenials = 0;
  int _dependencyResolutionFailures = 0;

  // ── Record Methods ──

  void recordCompositionDuration(int ms) => _totalCompositionDurationMs = ms;
  void recordDashboardCompositionDuration(int ms) => _dashboardCompositionDurationMs = ms;
  void recordHomeCompositionDuration(int ms) => _homeCompositionDurationMs = ms;
  void recordCommandPaletteCompositionDuration(int ms) => _commandPaletteCompositionDurationMs = ms;

  void recordDashboardWidgetCount(int count) => _dashboardWidgetCount = count;
  void recordHomeWidgetCount(int count) => _homeWidgetCount = count;
  void recordQuickActionCount(int count) => _quickActionCount = count;
  void recordRouteCount(int count) => _routeCount = count;
  void recordNotificationProviderCount(int count) => _notificationProviderCount = count;
  void recordSearchProviderCount(int count) => _searchProviderCount = count;
  void recordAnalyticsProviderCount(int count) => _analyticsProviderCount = count;
  void recordAIProviderCount(int count) => _aiProviderCount = count;
  void recordCommandPaletteActionCount(int count) => _commandPaletteActionCount = count;
  void recordBackgroundJobCount(int count) => _backgroundJobCount = count;
  void recordFABCount(int count) => _fabCount = count;
  void recordSettingsPageCount(int count) => _settingsPageCount = count;
  void recordReportCount(int count) => _reportCount = count;
  void recordExportProviderCount(int count) => _exportProviderCount = count;
  void recordImportProviderCount(int count) => _importProviderCount = count;
  void recordActivityTimelineItemCount(int count) => _activityTimelineItemCount = count;
  void recordHelpArticleCount(int count) => _helpArticleCount = count;
  void recordContextMenuCount(int count) => _contextMenuCount = count;
  void recordEntityActionCount(int count) => _entityActionCount = count;
  void recordWorkflowStepCount(int count) => _workflowStepCount = count;
  void recordApprovalActionCount(int count) => _approvalActionCount = count;

  void recordModulesWithContributions(int count) => _modulesWithContributions = count;
  void recordTotalModulesProcessed(int count) => _totalModulesProcessed = count;
  void recordFailedModuleContribution() => _failedModuleContributions++;
  void recordPermissionDenial() => _permissionDenials++;
  void recordDependencyResolutionFailure() => _dependencyResolutionFailures++;

  /// Take a snapshot and reset counters
  ContributionMetrics takeSnapshot() {
    final metrics = ContributionMetrics(
      totalCompositionDurationMs: _totalCompositionDurationMs,
      dashboardCompositionDurationMs: _dashboardCompositionDurationMs,
      homeCompositionDurationMs: _homeCompositionDurationMs,
      commandPaletteCompositionDurationMs: _commandPaletteCompositionDurationMs,
      dashboardWidgetCount: _dashboardWidgetCount,
      homeWidgetCount: _homeWidgetCount,
      quickActionCount: _quickActionCount,
      routeCount: _routeCount,
      notificationProviderCount: _notificationProviderCount,
      searchProviderCount: _searchProviderCount,
      analyticsProviderCount: _analyticsProviderCount,
      aiProviderCount: _aiProviderCount,
      commandPaletteActionCount: _commandPaletteActionCount,
      backgroundJobCount: _backgroundJobCount,
      fabCount: _fabCount,
      settingsPageCount: _settingsPageCount,
      reportCount: _reportCount,
      exportProviderCount: _exportProviderCount,
      importProviderCount: _importProviderCount,
      activityTimelineItemCount: _activityTimelineItemCount,
      helpArticleCount: _helpArticleCount,
      contextMenuCount: _contextMenuCount,
      entityActionCount: _entityActionCount,
      workflowStepCount: _workflowStepCount,
      approvalActionCount: _approvalActionCount,
      modulesWithContributions: _modulesWithContributions,
      totalModulesProcessed: _totalModulesProcessed,
      failedModuleContributions: _failedModuleContributions,
      permissionDenials: _permissionDenials,
      dependencyResolutionFailures: _dependencyResolutionFailures,
      estimatedMemoryUsageBytes: _estimateMemoryUsage(),
      recordedAt: DateTime.now(),
    );
    reset();
    return metrics;
  }

  /// Estimate memory usage of current contribution registrations
  int _estimateMemoryUsage() {
    // Rough estimate: each contribution ~200 bytes
    const bytesPerContribution = 200;
    final total = _dashboardWidgetCount +
        _homeWidgetCount +
        _quickActionCount +
        _routeCount +
        _notificationProviderCount +
        _searchProviderCount +
        _analyticsProviderCount +
        _aiProviderCount +
        _commandPaletteActionCount +
        _backgroundJobCount +
        _fabCount +
        _settingsPageCount +
        _reportCount +
        _exportProviderCount +
        _importProviderCount +
        _activityTimelineItemCount +
        _helpArticleCount +
        _contextMenuCount +
        _entityActionCount +
        _workflowStepCount +
        _approvalActionCount;
    return total * bytesPerContribution;
  }

  /// Reset all counters
  void reset() {
    _totalCompositionDurationMs = 0;
    _dashboardCompositionDurationMs = 0;
    _homeCompositionDurationMs = 0;
    _commandPaletteCompositionDurationMs = 0;
    _dashboardWidgetCount = 0;
    _homeWidgetCount = 0;
    _quickActionCount = 0;
    _routeCount = 0;
    _notificationProviderCount = 0;
    _searchProviderCount = 0;
    _analyticsProviderCount = 0;
    _aiProviderCount = 0;
    _commandPaletteActionCount = 0;
    _backgroundJobCount = 0;
    _fabCount = 0;
    _settingsPageCount = 0;
    _reportCount = 0;
    _exportProviderCount = 0;
    _importProviderCount = 0;
    _activityTimelineItemCount = 0;
    _helpArticleCount = 0;
    _contextMenuCount = 0;
    _entityActionCount = 0;
    _workflowStepCount = 0;
    _approvalActionCount = 0;
    _modulesWithContributions = 0;
    _totalModulesProcessed = 0;
    _failedModuleContributions = 0;
    _permissionDenials = 0;
    _dependencyResolutionFailures = 0;
  }
}

/// Singleton instance
final contributionMetricsCollector = ContributionMetricsCollector();

/// ============================================================
/// CONTRIBUTION METRICS PROVIDER (OBSERVABILITY)
/// ============================================================
///
/// A Riverpod provider that exposes the latest contribution metrics.
/// ============================================================



final contributionMetricsProvider = Provider<ContributionMetrics>((ref) {
  return contributionMetricsCollector.takeSnapshot();
});
