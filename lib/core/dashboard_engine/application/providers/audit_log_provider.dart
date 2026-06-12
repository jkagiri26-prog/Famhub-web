/// ============================================================
/// AUDIT LOG PROVIDERS — APPLICATION LAYER
/// ============================================================
///
/// PURPOSE:
/// Exposes AuditLogSink to the Riverpod provider graph.
/// Enables reactive consumption of audit log state.
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/providers/ = provider wiring
///
/// ✅ PROVIDERS:
///   - auditLogSinkProvider — singleton AuditLogSink instance
///   - auditLogErrorsProvider — reactive error/critical log entries
///   - auditLogCountProvider — current log count
///
/// ❌ Does NOT:
///   - Replace ObservabilityLogger
///   - Introduce new logging frameworks
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/observability/audit_log_sink.dart';

/// Singleton provider for the AuditLogSink
final auditLogSinkProvider = Provider<AuditLogSink>((ref) {
  return AuditLogSink(
    maxEntries: 1000,
    enableTelemetryCorrelation: true,
  );
});

/// Provider for error/critical audit entries (updates on each access)
final auditLogErrorsProvider = Provider<List<AuditLogEntry>>((ref) {
  final sink = ref.watch(auditLogSinkProvider);
  return sink.errors;
});

/// Provider for current log count
final auditLogCountProvider = Provider<int>((ref) {
  final sink = ref.watch(auditLogSinkProvider);
  return sink.length;
});
