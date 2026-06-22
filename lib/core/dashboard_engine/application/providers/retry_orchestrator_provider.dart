// ignore: dangling_library_doc_comments
/// ============================================================
/// RETRY ORCHESTRATOR PROVIDER — APPLICATION LAYER
/// ============================================================
///
/// PURPOSE:
/// Exposes RetryOrchestrator instances to the Riverpod provider
/// graph with configurable retry policies.
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/providers/ = provider wiring
///
/// ✅ PROVIDERS:
///   - retryOrchestratorProvider — default retry orchestrator
///   - retryOrchestratorProvider.family — policy-specific instances
///
/// ❌ Does NOT:
///   - Replace SafeDashboardPatchExecutor
///   - Manage patch state
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/executor/retry_orchestrator.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/observability_providers.dart';

/// Default retry orchestrator with exponential backoff
final defaultRetryOrchestratorProvider = Provider<RetryOrchestrator>((ref) {
  final collector = ref.read(runtimeMetricsCollectorProvider);
  return RetryOrchestrator(
    policy: RetryPolicy.exponential(
      maxAttempts: 3,
      baseDelayMs: 100,
      maxDelayMs: 2000,
      backoffFactor: 2.0,
    ),
    metricsCollector: collector,
  );
});

/// Policy-specific retry orchestrator provider
final retryOrchestratorProvider =
    Provider.family<RetryOrchestrator, RetryPolicy>((ref, policy) {
  final collector = ref.read(runtimeMetricsCollectorProvider);
  return RetryOrchestrator(
    policy: policy,
    metricsCollector: collector,
  );
});
