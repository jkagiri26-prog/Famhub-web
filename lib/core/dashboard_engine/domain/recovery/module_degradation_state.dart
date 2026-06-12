/// ============================================================
/// MODULE DEGRADATION STATE — DOMAIN MODEL
/// ============================================================
///
/// PURPOSE:
/// Represents the health and degradation state of a single module
/// at runtime. Enables per-module degradation policies (G1),
/// dependency recovery (G3), and graceful module isolation (G4).
///
/// Each module transitions through degradation levels:
///   Normal → Warning → Degraded → Isolated
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/domain/recovery/ = domain models for recovery
///
/// ✅ Used by:
///   - ModuleDegradationResolver (recovery orchestration)
///   - dashboard_runtime_validator (input to recovery)
///   - Module isolation providers
///
/// ❌ NOT:
///   - A widget or UI component
///   - A Riverpod provider (fed INTO providers)
///   - A replacement for ModuleRuntimeState
/// ============================================================

/// Possible degradation levels for a module
enum DegradationLevel {
  /// Module operating normally — no issues
  normal,

  /// Module has warnings — performance degradation detected
  /// but still functional. Monitoring active.
  warning,

  /// Module is degraded — validation failures or excessive errors.
  /// Fallback UI shown. Recovery attempts active.
  degraded,

  /// Module is isolated — fully removed from composition.
  /// Dependency chain broken. Requires manual or systematic recovery.
  isolated,
}

/// ============================================================
/// MODULE DEGRADATION ENTRY
/// ============================================================
///
/// Tracks the degradation state of a single module.
///
/// Each entry records:
/// - Current degradation level
/// - When degradation started
/// - Reason for degradation
/// - Whether automatic recovery is enabled
/// - Number of recovery attempts made
/// - IDs of dependent modules affected
/// ============================================================
class ModuleDegradationEntry {
  /// Module identifier
  final String moduleId;

  /// Current degradation level
  final DegradationLevel level;

  /// Timestamp when this degradation level was entered
  final DateTime degradedAt;

  /// Human-readable reason for degradation
  final String reason;

  /// Whether automatic recovery is currently enabled
  final bool autoRecoveryEnabled;

  /// Number of recovery attempts made since last transition
  final int recoveryAttemptCount;

  /// Set of module IDs that depend on this module
  /// (denormalized from DependencyRegistry for fast lookup)
  final Set<String> dependentModuleIds;

  /// Widget key that triggered the degradation (if applicable)
  final String? triggeringWidgetKey;

  /// Validation failure type that caused the degradation (if applicable)
  final String? failureType;

  const ModuleDegradationEntry({
    required this.moduleId,
    required this.level,
    required this.degradedAt,
    required this.reason,
    this.autoRecoveryEnabled = true,
    this.recoveryAttemptCount = 0,
    this.dependentModuleIds = const {},
    this.triggeringWidgetKey,
    this.failureType,
  });

  /// True if this module can be rendered (even with degraded UI)
  bool get isRenderable => level != DegradationLevel.isolated;

  /// True if this module is healthy
  bool get isHealthy => level == DegradationLevel.normal;

  /// True if this module requires attention
  bool get requiresAttention =>
      level == DegradationLevel.warning ||
      level == DegradationLevel.degraded;

  /// Create a copy with updated fields
  ModuleDegradationEntry copyWith({
    DegradationLevel? level,
    DateTime? degradedAt,
    String? reason,
    bool? autoRecoveryEnabled,
    int? recoveryAttemptCount,
    Set<String>? dependentModuleIds,
    String? triggeringWidgetKey,
    String? failureType,
  }) {
    return ModuleDegradationEntry(
      moduleId: moduleId,
      level: level ?? this.level,
      degradedAt: degradedAt ?? this.degradedAt,
      reason: reason ?? this.reason,
      autoRecoveryEnabled:
          autoRecoveryEnabled ?? this.autoRecoveryEnabled,
      recoveryAttemptCount:
          recoveryAttemptCount ?? this.recoveryAttemptCount,
      dependentModuleIds:
          dependentModuleIds ?? this.dependentModuleIds,
      triggeringWidgetKey:
          triggeringWidgetKey ?? this.triggeringWidgetKey,
      failureType: failureType ?? this.failureType,
    );
  }

  @override
  String toString() =>
      'ModuleDegradationEntry($moduleId | $level | attempt=$recoveryAttemptCount)';
}

/// ============================================================
/// MODULE DEGRADATION SNAPSHOT
/// ============================================================
///
/// Immutable snapshot of all module degradation states.
/// Consumed by providers and diagnostics panels.
/// ============================================================
class ModuleDegradationSnapshot {
  /// Map of moduleId → degradation entry
  final Map<String, ModuleDegradationEntry> entries;

  /// Timestamp of this snapshot
  final DateTime snapshotAt;

  const ModuleDegradationSnapshot({
    required this.entries,
    required this.snapshotAt,
  });

  /// Get degradation for a specific module
  ModuleDegradationEntry? forModule(String moduleId) =>
      entries[moduleId];

  /// Modules currently degraded (warning or worse)
  List<ModuleDegradationEntry> get degradedModules =>
      entries.values
          .where((e) => e.requiresAttention)
          .toList()
        ..sort((a, b) => a.level.index.compareTo(b.level.index));

  /// Modules currently isolated
  List<ModuleDegradationEntry> get isolatedModules =>
      entries.values
          .where((e) => e.level == DegradationLevel.isolated)
          .toList();

  /// Healthy modules
  List<ModuleDegradationEntry> get healthyModules =>
      entries.values
          .where((e) => e.isHealthy)
          .toList();

  /// Number of degraded modules
  int get degradedCount =>
      entries.values.where((e) => e.requiresAttention).length;

  /// Number of isolated modules
  int get isolatedCount =>
      entries.values.where((e) => e.level == DegradationLevel.isolated).length;

  /// Overall system health based on module degradation
  SystemDegradationHealth get systemHealth {
    if (isolatedCount > 0) return SystemDegradationHealth.critical;
    if (degradedCount > 3) return SystemDegradationHealth.degraded;
    if (degradedCount > 0) return SystemDegradationHealth.warning;
    return SystemDegradationHealth.healthy;
  }

  @override
  String toString() =>
      'ModuleDegradationSnapshot(healthy=${healthyModules.length}, '
      'degraded=$degradedCount, isolated=$isolatedCount)';
}

/// Overall system degradation health
enum SystemDegradationHealth {
  healthy,
  warning,
  degraded,
  critical,
}
