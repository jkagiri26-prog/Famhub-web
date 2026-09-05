/// ============================================================
/// LISTING EDIT — USER-FRIENDLY ERROR MAPPING
/// ============================================================
///
/// Maps expected Listing-Edit / status-mutation failures into user-friendly
/// copy. The backend stays authoritative — this mapping only translates
/// failure responses for display. It never exposes SQL, function names,
/// SECURITY DEFINER details, UUIDs or stack traces to the user.
/// ============================================================
library;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Friendly message for a failed metadata save.
String describeListingSaveError(Object error) {
  return _describe(
    error,
    signInMessage: 'Please sign in to edit this listing.',
    unauthorizedMessage: "You don't have permission to edit this listing.",
    unavailableMessage: 'This listing is no longer available.',
    invalidValueMessage:
        'Some listing details are invalid. Review the fields and try again.',
    genericMessage: "We couldn't update the listing. Please try again.",
    extraChecks: (text) {
      if (text.contains('price') ||
          text.contains('greater than zero') ||
          text.contains('greater than 0') ||
          text.contains('positive') ||
          text.contains('numeric')) {
        return 'Enter a valid price greater than zero.';
      }
      return null;
    },
  );
}

/// Friendly message for a failed activate / deactivate action.
String describeListingStatusError(Object error, {required bool activating}) {
  final generic = activating
      ? "We couldn't activate the listing. Please try again."
      : "We couldn't deactivate the listing. Please try again.";

  return _describe(
    error,
    signInMessage: 'Please sign in to manage this listing.',
    unauthorizedMessage: "You don't have permission to manage this listing.",
    unavailableMessage: 'This listing is no longer available.',
    invalidValueMessage: 'That listing status is not available.',
    genericMessage: generic,
    extraChecks: activating
        ? (String text) {
            if (text.contains('stock') ||
                text.contains('quantity') ||
                text.contains('insufficient') ||
                text.contains('not enough') ||
                text.contains('out of stock') ||
                text.contains('no available')) {
              return 'This listing cannot be activated because there is '
                  'no available stock.';
            }
            return null;
          }
        : null,
  );
}

String _describe(
  Object error, {
  required String signInMessage,
  required String unauthorizedMessage,
  required String unavailableMessage,
  required String invalidValueMessage,
  required String genericMessage,
  String? Function(String text)? extraChecks,
}) {
  if (error is PostgrestException) {
    final text = _postgrestText(error);
    final extra = extraChecks?.call(text);
    if (extra != null) return extra;

    if (_containsAny(text, const [
      'jwt',
      'expired',
      'token',
      'sign in',
      'log in',
      'logged in',
      'authenticated',
      'authentication',
      'session',
    ])) {
      return signInMessage;
    }

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
      'can_manage',
      'privilege',
      'policy',
    ])) {
      return unauthorizedMessage;
    }

    if (_containsAny(text, const [
      '404',
      'pgrst116',
      'no rows',
      'not found',
      'does not exist',
      'no longer available',
    ])) {
      return unavailableMessage;
    }

    if (_containsAny(text, const [
      'price',
      'greater than zero',
      'greater than 0',
      'positive',
      '23514',
      'violates check',
      'violates constraint',
      'invalid',
      'status',
      'required',
      'too long',
    ])) {
      return invalidValueMessage;
    }

    return genericMessage;
  }

  final text = '$error'.toLowerCase();
  final extra = extraChecks?.call(text);
  if (extra != null) return extra;

  if (text.contains('permission') ||
      text.contains('denied') ||
      text.contains('authoriz')) {
    return unauthorizedMessage;
  }
  if (text.contains('no longer available') ||
      text.contains('not found') ||
      text.contains('no rows')) {
    return unavailableMessage;
  }
  if (text.contains('invalid') ||
      text.contains('price') ||
      text.contains('status')) {
    return invalidValueMessage;
  }
  if (text.contains('socket') ||
      text.contains('timeout') ||
      text.contains('connection') ||
      text.contains('network') ||
      text.contains('client exception') ||
      error is http.ClientException) {
    return genericMessage;
  }
  return genericMessage;
}

String _postgrestText(PostgrestException error) {
  final code = (error.code ?? '').toLowerCase();
  final message = error.message.toLowerCase();
  final details = (error.details?.toString() ?? '').toLowerCase();
  return '$code $message $details';
}

bool _containsAny(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) return true;
  }
  return false;
}
