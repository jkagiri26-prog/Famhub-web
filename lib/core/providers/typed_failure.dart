// ignore: dangling_library_doc_comments
/// ============================================================
/// TYPED FAILURE MODEL — APPLICATION LAYER
/// ============================================================
///
/// PURPOSE:
/// Provides a typed failure model for Riverpod AsyncValue error
/// handling. Enables pattern matching on failure types rather
/// than checking raw error strings.
///
/// This is the GAP-CLOSURE for G6: "No typed failure integration
/// with AsyncValue.guard()."
///
/// 🧠 LOCATION CONTEXT:
///   core/providers/ = shared provider infrastructure
///
/// ✅ USAGE:
/// ```dart
/// final result = await AsyncValue.guard(() => service.call());
/// if (result.hasError) {
///   final failure = TypedFailure.fromError(result.error);
///   if (failure is NetworkFailure) { ... }
///   if (failure is AuthFailure) { ... }
/// }
/// ```
///
/// ❌ Does NOT:
///   - Replace existing error handling
///   - Modify existing providers
///   - Introduce breaking changes
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base failure type
sealed class TypedFailure {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const TypedFailure({
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  /// Create a TypedFailure from a generic error
  static TypedFailure fromError(
    Object error, [
    StackTrace? stack,
  ]) {
    if (error is TypedFailure) return error;

    final message = error.toString();

    if (message.contains('Network') || message.contains('network')) {
      return NetworkFailure(
        message: message,
        originalError: error,
        stackTrace: stack,
      );
    }
    if (message.contains('Auth') || message.contains('auth')) {
      return AuthFailure(
        message: message,
        originalError: error,
        stackTrace: stack,
      );
    }
    if (message.contains('Permission') || message.contains('permission') ||
        message.contains('Access')) {
      return PermissionFailure(
        message: message,
        originalError: error,
        stackTrace: stack,
      );
    }
    if (message.contains('Not found') || message.contains('not_found')) {
      return NotFoundFailure(
        message: message,
        originalError: error,
        stackTrace: stack,
      );
    }
    if (message.contains('Timeout') || message.contains('timeout')) {
      return TimeoutFailure(
        message: message,
        originalError: error,
        stackTrace: stack,
      );
    }
    if (message.contains('Validation') || message.contains('validation')) {
      return ValidationFailure(
        message: message,
        originalError: error,
        stackTrace: stack,
      );
    }

    return UnknownFailure(
      message: message,
      originalError: error,
      stackTrace: stack,
    );
  }
}

/// Network connectivity failure
class NetworkFailure extends TypedFailure {
  const NetworkFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}

/// Authentication failure
class AuthFailure extends TypedFailure {
  const AuthFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}

/// Permission/access failure
class PermissionFailure extends TypedFailure {
  const PermissionFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}

/// Resource not found failure
class NotFoundFailure extends TypedFailure {
  const NotFoundFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}

/// Timeout failure
class TimeoutFailure extends TypedFailure {
  const TimeoutFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}

/// Validation failure
class ValidationFailure extends TypedFailure {
  const ValidationFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}

/// Unknown/unclassified failure
class UnknownFailure extends TypedFailure {
  const UnknownFailure({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}

/// ============================================================
/// TYPED FAILURE EXTENSION ON AsyncValue
/// ============================================================
///
/// Adds `.failure` getter to AsyncValue for typed failure access.
///
/// Usage:
/// ```dart
/// ref.watch(someProvider).failure // TypedFailure?
/// ```
/// ============================================================
extension TypedAsyncValue<T> on AsyncValue<T> {
  /// Get the typed failure from this AsyncValue
  TypedFailure? get typedFailure {
    if (!hasError || error == null) return null;
    return TypedFailure.fromError(error!, stackTrace);
  }
}
