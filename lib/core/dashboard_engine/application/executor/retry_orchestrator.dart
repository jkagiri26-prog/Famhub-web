import 'dart:async';
import 'dart:math';

import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/observability/runtime_metrics_collector.dart';

/// ============================================================
/// RETRY RESULT — PHASE 3 EXPANSION
/// ============================================================
/// 
/// PHASE 3 EXTENSIONS:
/// - Recovery tracking metadata
/// - Observability correlation (telemetry event linkage)
/// - Module-specific failure context
///
class RetryResult<T> {
  /// Whether the operation succeeded
  final bool success;

  /// The result value (if successful)
  final T? value;

  /// The last error (if all attempts failed)
  final Object? error;

  /// Number of attempts made
  final int attemptsMade;

  /// Total duration of all attempts
  final Duration totalDuration;

  /// PHASE 3: Recovery tracking
  final bool recoveryAttempted;
  final bool recoverySucceeded;
  final String? recoveryMethod;
  final RuntimeHealthStatus? postRecoveryHealth;
  final int failureSequenceId;

  const RetryResult({
    required this.success,
    this.value,
    this.error,
    required this.attemptsMade,
    required this.totalDuration,
    this.recoveryAttempted = false,
    this.recoverySucceeded = false,
    this.recoveryMethod,
    this.postRecoveryHealth,
    this.failureSequenceId = 0,
  });

  bool get failed => !success;
}

/// ============================================================
/// RETRY POLICY
/// ============================================================
class RetryPolicy {
  /// Maximum number of attempts (including first)
  final int maxAttempts;

  /// Base delay in milliseconds
  final int baseDelayMs;

  /// Maximum delay in milliseconds
  final int maxDelayMs;

  /// Exponential backoff factor
  final double backoffFactor;

  /// Whether to retry on all errors, or only specific ones
  final bool retryOnAllErrors;

  /// Error types to retry on (if retryOnAllErrors is false)
  final List<Type> retryableErrorTypes;

  const RetryPolicy._({
    required this.maxAttempts,
    this.baseDelayMs = 100,
    this.maxDelayMs = 5000,
    this.backoffFactor = 2.0,
    this.retryOnAllErrors = true,
    this.retryableErrorTypes = const [],
  });

  /// No retry — execute once
  factory RetryPolicy.none() =>
      const RetryPolicy._(maxAttempts: 1);

  /// Simple fixed retry with constant delay
  factory RetryPolicy.simple({
    int maxAttempts = 3,
    int delayMs = 200,
  }) =>
      RetryPolicy._(
        maxAttempts: maxAttempts,
        baseDelayMs: delayMs,
        backoffFactor: 1.0,
      );

  /// Exponential backoff retry
  factory RetryPolicy.exponential({
    int maxAttempts = 3,
    int baseDelayMs = 100,
    int maxDelayMs = 5000,
    double backoffFactor = 2.0,
  }) =>
      RetryPolicy._(
        maxAttempts: maxAttempts,
        baseDelayMs: baseDelayMs,
        maxDelayMs: maxDelayMs,
        backoffFactor: backoffFactor,
      );

  /// Adaptive retry that only retries on specific error types
  factory RetryPolicy.adaptive({
    int maxAttempts = 3,
    int baseDelayMs = 100,
    required List<Type> retryableErrorTypes,
  }) =>
      RetryPolicy._(
        maxAttempts: maxAttempts,
        baseDelayMs: baseDelayMs,
        retryOnAllErrors: false,
        retryableErrorTypes: retryableErrorTypes,
      );

  bool get canRetry => maxAttempts > 1;
}

/// ============================================================
/// RETRY ORCHESTRATOR — PHASE 3 EXPANSION
/// ============================================================
///
/// PHASE 3 EXTENSIONS:
/// - Recovery tracking with runtime metrics collector integration
/// - Telemetry event emission for retry operations
/// - Module-specific failure sequence tracking
/// ============================================================
class RetryOrchestrator {
  final RetryPolicy policy;
  final void Function(String message)? logger;
  final RuntimeMetricsCollector? metricsCollector;

  // PHASE 3: Failure sequence tracking
  final Map<String, int> _moduleFailureSequences = {};

  RetryOrchestrator({
    required this.policy,
    this.logger,
    this.metricsCollector,
  });

  /// PHASE 3: Record a recovery telemetry event
  void _recordRecoveryTelemetry({
    required String moduleId,
    required bool success,
    String? recoveryMethod,
  }) {
    if (metricsCollector == null) return;

    final event = RuntimeTelemetryEvent(
      traceId: 'retry_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      type: success
          ? TelemetryEventType.syncReconnectSucceeded
          : TelemetryEventType.syncReconnectFailed,
      moduleId: moduleId,
      durationMs: 0,
      phase: TelemetryPhase.execution,
      severity: success ? TelemetrySeverity.info : TelemetrySeverity.warning,
    );
    metricsCollector!.record(event);
  }

  /// PHASE 3: Get or increment failure sequence for a module
  int _getFailureSequence(String moduleId) {
    _moduleFailureSequences.putIfAbsent(moduleId, () => 0);
    _moduleFailureSequences[moduleId] = _moduleFailureSequences[moduleId]! + 1;
    return _moduleFailureSequences[moduleId]!;
  }

  /// PHASE 3: Reset failure sequence for a module (on success)
  void _resetFailureSequence(String moduleId) {
    _moduleFailureSequences[moduleId] = 0;
  }

  /// ============================================================
  /// EXECUTE AN OPERATION WITH RETRY
  /// ============================================================
  ///
  /// Wraps an async operation with the configured retry policy.
  ///
  /// [operation] — The async operation to execute
  /// [operationName] — Name for logging
  /// [shouldRetry] — Optional custom retry decision function
  /// [moduleId] — Optional module ID for failure sequence tracking
  ///
  /// Returns a RetryResult with the outcome.
  /// ============================================================
  Future<RetryResult<T>> execute<T>({
    required Future<T> Function() operation,
    String operationName = 'unknown',
    bool Function(Object error)? shouldRetry,
    String? moduleId,
  }) async {
    final sw = Stopwatch()..start();
    int attempts = 0;
    Object? lastError;

    while (attempts < policy.maxAttempts) {
      attempts++;

      try {
        final result = await operation();
        sw.stop();

        _log('$operationName succeeded on attempt $attempts '
            '(${sw.elapsedMilliseconds}ms)');

        // Reset failure sequence on success
        if (moduleId != null) _resetFailureSequence(moduleId);

        return RetryResult(
          success: true,
          value: result,
          attemptsMade: attempts,
          totalDuration: sw.elapsed,
          failureSequenceId: moduleId != null
              ? (_moduleFailureSequences[moduleId] ?? 0)
              : 0,
        );
      } catch (e) {
        lastError = e;
        sw.stop();

        // Track failure sequence
        if (moduleId != null) _getFailureSequence(moduleId);

        _log('$operationName failed on attempt $attempts: $e');

        // Check if we should retry
        if (attempts >= policy.maxAttempts) {
          break;
        }

        // Check custom retry decision
        if (shouldRetry != null && !shouldRetry(e)) {
          _log('Custom retry check returned false. Stopping retries.');
          break;
        }

        // Check error type filter
        if (!policy.retryOnAllErrors) {
          final isRetryable = policy.retryableErrorTypes
              .any((type) => type.isInstance(e));
          if (!isRetryable) {
            _log('Error type not retryable. Stopping retries.');
            break;
          }
        }

        // Calculate delay
        final delayMs = _calculateDelay(attempts);
        _log('Retrying in ${delayMs}ms...');

        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    sw.stop();
    _log('$operationName failed after $attempts attempts '
        '(${sw.elapsedMilliseconds}ms total)');

    // Record recovery failure telemetry
    if (moduleId != null) {
      _recordRecoveryTelemetry(
        moduleId: moduleId,
        success: false,
        recoveryMethod: 'retry_exhausted',
      );
    }

    return RetryResult(
      success: false,
      error: lastError,
      attemptsMade: attempts,
      totalDuration: sw.elapsed,
      failureSequenceId: moduleId != null
          ? (_moduleFailureSequences[moduleId] ?? 0)
          : 0,
    );
  }

  /// ============================================================
  /// EXECUTE WITH RECOVERY (PHASE 3)
  /// ============================================================
  ///
  /// Executes with retry and automatic recovery tracking.
  /// Used when a module-specific operation fails and needs
  /// observability correlation.
  ///
  /// [moduleId] — Module being operated on
  /// [recoveryMethod] — Name of the recovery strategy used
  /// ============================================================
  Future<RetryResult<T>> executeWithRecovery<T>({
    required Future<T> Function() operation,
    required String moduleId,
    String operationName = 'unknown',
    String recoveryMethod = 'default',
  }) async {
    final result = await execute<T>(
      operation: operation,
      operationName: operationName,
      moduleId: moduleId,
    );

    if (result.success) {
      _recordRecoveryTelemetry(
        moduleId: moduleId,
        success: true,
        recoveryMethod: recoveryMethod,
      );
    }

    return RetryResult(
      success: result.success,
      value: result.value,
      error: result.error,
      attemptsMade: result.attemptsMade,
      totalDuration: result.totalDuration,
      recoveryAttempted: !result.success,
      recoverySucceeded: result.success,
      recoveryMethod: recoveryMethod,
      failureSequenceId: result.failureSequenceId,
    );
  }

  /// ============================================================
  /// EXECUTE WITH FALLBACK
  /// ============================================================
  ///
  /// Executes the primary operation with retry, and falls back
  /// to a secondary operation if all retries fail.
  ///
  /// [primary] — Main operation with retry
  /// [fallback] — Fallback operation (executed once)
  /// ============================================================
  Future<RetryResult<T>> executeWithFallback<T>({
    required Future<T> Function() primary,
    required Future<T> Function() fallback,
    String operationName = 'unknown',
  }) async {
    final result = await execute(
      operation: primary,
      operationName: operationName,
    );

    if (result.failed) {
      _log('$operationName: executing fallback after ${result.attemptsMade} attempts');
      try {
        final fallbackResult = await fallback();
        return RetryResult(
          success: true,
          value: fallbackResult,
          attemptsMade: result.attemptsMade + 1,
          totalDuration: result.totalDuration,
        );
      } catch (e) {
        return RetryResult(
          success: false,
          error: e,
          attemptsMade: result.attemptsMade + 1,
          totalDuration: result.totalDuration,
        );
      }
    }

    return result;
  }

  // ─── PRIVATE ──────────────────────────────────────────────

  int _calculateDelay(int attempt) {
    final rawDelay = policy.baseDelayMs *
        pow(policy.backoffFactor, attempt - 1).toInt();
    return rawDelay.clamp(0, policy.maxDelayMs);
  }

  void _log(String message) {
    logger?.call('[RetryOrchestrator] $message');
  }
}

/// Extension to check if object is instance of a type
extension _TypeCheck on Type {
  bool isInstance(Object object) => object.runtimeType == this;
}
