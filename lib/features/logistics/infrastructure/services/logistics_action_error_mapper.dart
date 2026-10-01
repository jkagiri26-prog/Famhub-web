/// ============================================================
/// LOGISTICS — USER-FRIENDLY ACTION ERROR MAPPING
/// ============================================================
///
/// Translates expected Logistics action failures (transport assignment,
/// tracking lifecycle, GPS submission) into copy that is safe to show.
/// The backend stays authoritative — this mapping only translates
/// failure responses for display. It never exposes SQL, function names,
/// SECURITY DEFINER details, UUIDs or stack traces to the user.
/// ============================================================
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Friendly message for a failed transport assignment.
String describeAssignTransportError(Object error) {
  return _describe(
    error,
    signInMessage: 'Please sign in to assign transport.',
    unauthorizedMessage:
        "You don't have permission to assign transport for this shipment.",
    unavailableMessage: 'This shipment is no longer available to assign.',
    invalidMessage:
        'Select a transport provider before assigning this shipment.',
    genericMessage: "We couldn't assign transport. Please try again.",
    extraChecks: (text) {
      if (text.contains('provider')) {
        return 'Select a transport provider before assigning this shipment.';
      }
      if (text.contains('already') || text.contains('duplicate')) {
        return 'This shipment already has an active transport assignment.';
      }
      return null;
    },
  );
}

/// Friendly message for a failed tracking lifecycle transition.
String describeTrackingActionError(Object error) {
  return _describe(
    error,
    signInMessage: 'Please sign in to update tracking.',
    unauthorizedMessage:
        "You don't have permission to update tracking for this shipment.",
    unavailableMessage: 'This tracking session is no longer available.',
    invalidMessage: 'That tracking action is not available right now.',
    genericMessage: "We couldn't update tracking. Please try again.",
    extraChecks: (text) {
      if (text.contains('driver') || text.contains('assigned')) {
        return 'Only the assigned driver can update this tracking session.';
      }
      if (text.contains('terminal') ||
          text.contains('completed') ||
          text.contains('cancelled')) {
        return 'This tracking session has already ended.';
      }
      return null;
    },
  );
}

/// Friendly message for a failed GPS point submission.
String describeLocationPointError(Object error) {
  return _describe(
    error,
    signInMessage: 'Please sign in to record your location.',
    unauthorizedMessage: "You don't have permission to record location.",
    unavailableMessage: 'This tracking session is no longer recording.',
    invalidMessage: 'That location reading is not valid.',
    genericMessage:
        "We couldn't record your location. It is saved on this device "
        'and will be retried.',
    extraChecks: (text) {
      if (text.contains('latitude') || text.contains('longitude')) {
        return 'That location reading is not valid.';
      }
      if (text.contains('idempotency')) {
        return 'That location reading was already recorded.';
      }
      return null;
    },
  );
}

String _describe(
  Object error, {
  required String signInMessage,
  required String unauthorizedMessage,
  required String unavailableMessage,
  required String invalidMessage,
  required String genericMessage,
  String? Function(String text)? extraChecks,
}) {
  final text = _errorText(error);
  final extra = extraChecks?.call(text);
  if (extra != null) return extra;

  if (_containsAny(text, const [
    'socket',
    'connection',
    'network',
    'timeout',
    'timed out',
    'unreachable',
    'failed host lookup',
    'offline',
    'offline_error',
    'clientexception',
    'connection closed',
  ])) {
    return 'No connection. Check your network and try again.';
  }

  // Authorization first — RPC rejections are the most common failure and
  // must never be mistaken for a sign-in prompt (function names such as
  // `start_tracking_session` contain words like "session" or "auth").
  if (_containsAny(text, const [
    '42501',
    'permission',
    'denied',
    'deny',
    'authoriz',
    'authoris',
    'row-level',
    'row level',
    'security definer',
    'policy',
    'privilege',
    'forbidden',
    'not allowed',
  ])) {
    return unauthorizedMessage;
  }

  if (_containsAny(text, const [
    'jwt',
    'expired',
    'token',
    'sign in',
    'log in',
    'logged out',
    'not authenticated',
    'unauthenticated',
    'authentication',
  ])) {
    return signInMessage;
  }

  if (_containsAny(text, const [
    '404',
    'pgrst116',
    'no rows',
    'not found',
    'does not exist',
    'no longer available',
    'already ended',
  ])) {
    return unavailableMessage;
  }

  if (_containsAny(text, const [
    '23514',
    '23505',
    'violates check',
    'violates constraint',
    'invalid',
    'required',
    'null value',
    'too long',
    'must be',
  ])) {
    return invalidMessage;
  }

  return genericMessage;
}

String _errorText(Object error) {
  if (error is PostgrestException) {
    return [
      error.message,
      error.code ?? '',
      error.details?.toString() ?? '',
    ].join(' ').toLowerCase();
  }
  if (error is AuthException) {
    return 'authentication ${error.message}'.toLowerCase();
  }
  if (error is TimeoutException) return 'timeout';
  // SocketException / ClientException / HttpException surface through
  // toString() — e.g. "SocketException: Failed host lookup: api.x".
  return error.toString().toLowerCase();
}

bool _containsAny(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) return true;
  }
  return false;
}
