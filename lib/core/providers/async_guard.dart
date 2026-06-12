/// ============================================================
/// ASYNC GUARD — APPLICATION LAYER
/// ============================================================
///
/// PURPOSE:
/// Provides standardized AsyncValue.guard() patterns with typed
/// failure integration. Reduces boilerplate in provider definitions.
///
/// This is the COMPANION to typed_failure.dart (G6 closure).
///
/// 🧠 LOCATION CONTEXT:
///   core/providers/ = shared provider infrastructure
///
/// ✅ USAGE:
/// ```dart
/// // Basic guard with typed failure
/// final result = await AsyncGuard.guard(() => service.call());
/// result.typedFailure // TypedFailure?
///
/// // In a FutureProvider:
/// final myProvider = FutureProvider((ref) async {
///   return AsyncGuard.guard(() => service.getData());
/// });
/// ```
///
/// ❌ Does NOT:
///   - Replace AsyncValue.guard() (wraps it)
///   - Modify existing providers
/// ============================================================

import 'dart:async';

import 'package:famhub_app/core/providers/typed_failure.dart';

/// ============================================================
/// ASYNC GUARD
/// ============================================================
class AsyncGuard {
  /// Guard an async operation with typed failure handling.
  ///
  /// This wraps `AsyncValue.guard()` and converts generic errors
  /// to TypedFailure instances.
  ///
  /// [operation] — The async operation to guard
  /// [onFailure] — Optional callback when a typed failure occurs
  ///
  /// Returns an AsyncValue with typed failure support.
  static Future<AsyncValue<T>> guard<T>(
    Future<T> Function() operation, {
    void Function(TypedFailure failure)? onFailure,
  }) async {
    return _GuardedOperation(
      operation: operation,
      onFailure: onFailure,
    ).execute();
  }

  /// Guard an operation with a specific timeout.
  static Future<AsyncValue<T>> guardWithTimeout<T>(
    Future<T> Function() operation, {
    required Duration timeout,
    void Function(TypedFailure failure)? onFailure,
  }) async {
    return _GuardedOperation(
      operation: () => operation().timeout(
        timeout,
        onTimeout: () => throw TimeoutFailure(
          message: 'Operation timed out after ${timeout.inMilliseconds}ms',
        ),
      ),
      onFailure: onFailure,
    ).execute();
  }

  /// Guard an operation with retry on failure.
  static Future<AsyncValue<T>> guardWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 200),
    void Function(TypedFailure failure)? onFailure,
  }) async {
    int attempts = 0;
    Object? lastError;

    while (attempts < maxRetries) {
      attempts++;
      try {
        final result = await operation();
        return AsyncValue.data(result);
      } catch (e) {
        lastError = e;
        if (attempts < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }

    final failure = TypedFailure.fromError(lastError!);
    onFailure?.call(failure);
    return AsyncValue.error(
      failure,
      failure.stackTrace ?? StackTrace.current,
    );
  }
}

/// Internal guarded operation
class _GuardedOperation<T> {
  final Future<T> Function() operation;
  final void Function(TypedFailure failure)? onFailure;

  _GuardedOperation({
    required this.operation,
    this.onFailure,
  });

  Future<AsyncValue<T>> execute() async {
    try {
      final result = await operation();

      // Check if result is already an AsyncValue
      if (result is AsyncValue<T>) {
        return result as AsyncValue<T>;
      }

      return AsyncValue.data(result);
    } catch (e, stack) {
      final failure = TypedFailure.fromError(e, stack);
      onFailure?.call(failure);
      return AsyncValue.error(failure, stack);
    }
  }
}
