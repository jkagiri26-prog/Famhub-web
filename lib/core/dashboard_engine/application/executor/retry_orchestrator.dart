/// ============================================================
/// RETRY ORCHESTRATOR — APPLICATION LAYER
/// ============================================================
///
/// PURPOSE:
/// Provides configurable retry logic for dashboard operations.
/// Wraps existing patch execution with retry policies.
///
/// This is the GAP-CLOSURE for G2: "No formal retry orchestration."
///
/// RETRY POLICIES:
///   - None: No retry (execute once)
///   - Simple: Fixed number of attempts with delay
///   - Exponential: Exponential backoff between retries
///   - Adaptive: Adjusts based on error type and system load
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/executor/ = patch execution layer
///
/// ✅ USAGE:
/// ```dart
/// final orchestrator = RetryOrchestrator(
///   policy: RetryPolicy.exponential(
///     maxAttempts: 3,
///     baseDelayMs: 100,
///   ),
/// );
///
/// final result = await orchestrator.execute(
///   operation: () => executor.execute(patch),
///   operationName: 'patch_execution',
/// );
/// ```
///
/// ❌ Does NOT:
///   - Replace SafeDashboardPatchExecutor
///   - Handle module state management
///   - Perform reconciliation
/// ============================================================

import 'dart:async';
import 'dart:math';

/// ============================================================
/// RETRY RESULT
/// ============================================================
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

  const RetryResult({
    required this.success,
    this.value,
    this.error,
    required this.attemptsMade,
    required this.totalDuration,
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
/// RETRY ORCHESTRATOR
/// ============================================================
class RetryOrchestrator {
  final RetryPolicy policy;
  final void Function(String message)? logger;

  const RetryOrchestrator({
    required this.policy,
    this.logger,
  });

  /// ============================================================
  /// EXECUTE AN OPERATION WITH RETRY
  /// ============================================================
  ///
  /// Wraps an async operation with the configured retry policy.
  ///
  /// [operation] — The async operation to execute
  /// [operationName] — Name for logging
  /// [shouldRetry] — Optional custom retry decision function
  ///
  /// Returns a RetryResult with the outcome.
  /// ============================================================
  Future<RetryResult<T>> execute<T>({
    required Future<T> Function() operation,
    String operationName = 'unknown',
    bool Function(Object error)? shouldRetry,
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

        return RetryResult(
          success: true,
          value: result,
          attemptsMade: attempts,
          totalDuration: sw.elapsed,
        );
      } catch (e) {
        lastError = e;
        sw.stop();

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
              .any((type) => type.isInstanceOfType(e));
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

    return RetryResult(
      success: false,
      error: lastError,
      attemptsMade: attempts,
      totalDuration: sw.elapsed,
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
extension _TypeCheck on Object {
  bool isInstanceOfType(Type type) => runtimeType == type;
}
