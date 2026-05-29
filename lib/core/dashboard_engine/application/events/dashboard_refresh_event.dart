import 'package:flutter/foundation.dart';

/// ============================================================
/// DASHBOARD REFRESH EVENT (DOMAIN SIGNAL MODEL)
/// ============================================================
///
/// Lightweight event used to trigger dashboard updates.
///
/// This is ONLY a signal carrier.
///
/// ❌ NOT responsible for:
/// - layout decisions
/// - module control
/// - state management
/// ============================================================
enum DashboardRefreshEventType {
  moduleActivation,
  featureFlagUpdate,
  entitySwitch,
  roleContextChange,
}

@immutable
class DashboardRefreshEvent {
  final DashboardRefreshEventType type;

  final DateTime timestamp;

  /// Optional module context (if event is module-scoped)
  final String? moduleKey;

  /// Event origin (system, user_action, backend_sync, etc.)
  final String? source;

  /// Flexible payload (must NOT contain logic)
  final Map<String, dynamic> metadata;

  const DashboardRefreshEvent({
    required this.type,
    required this.metadata,
    this.moduleKey,
    this.source,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// ============================================================
  /// VALUE EQUALITY (IMPORTANT FOR EVENT DEDUPE)
  /// ============================================================

  @override
  bool operator ==(Object other) {
    return other is DashboardRefreshEvent &&
        other.type == type &&
        other.moduleKey == moduleKey &&
        other.source == source &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(
        type,
        moduleKey,
        source,
        timestamp,
      );

  /// ============================================================
  /// DEBUG
  /// ============================================================

  @override
  String toString() =>
      'DashboardRefreshEvent(type: $type, moduleKey: $moduleKey, source: $source, timestamp: $timestamp)';
}