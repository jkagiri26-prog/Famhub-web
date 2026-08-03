/// ============================================================
/// OTP SESSION PROVIDER — Riverpod state management
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Manage the current OTP session state via Riverpod
///   - Handle session save, clear, and restore operations
///   - Auto-cleanup expired sessions
///
/// ❌ Does NOT:
///   - Contain UI logic
///   - Know about routing
///   - Call the backend directly (delegated to AuthService)
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/auth/domain/models/otp_session.dart';
import 'package:famhub_app/features/auth/infrastructure/services/otp_session_storage.dart';

/// ============================================================
/// OTP SESSION CONTROLLER
/// ============================================================
class OtpSessionController extends Notifier<OtpSession?> {
  @override
  OtpSession? build() {
    return null;
  }

  /// Save an OTP session to memory and persist to local storage.
  Future<void> saveSession(OtpSession session) async {
    state = session;
    await OtpSessionStorage.saveSession(session);
  }

  /// Clear the current OTP session from memory and local storage.
  Future<void> clearSession() async {
    state = null;
    await OtpSessionStorage.clearSession();
  }

  /// Restore the persisted OTP session from local storage.
  /// If the session is expired, it is cleared automatically.
  /// Returns the restored session (or null if none/expired).
  Future<OtpSession?> restoreSession() async {
    final session = await OtpSessionStorage.loadSession();
    if (session == null) {
      state = null;
      return null;
    }

    // Auto-cleanup expired sessions
    if (session.isExpired) {
      await OtpSessionStorage.clearSession();
      state = null;
      return null;
    }

    state = session;
    return session;
  }

  /// Check if there is an active, valid OTP session.
  bool hasActiveSession() {
    final session = state;
    return session != null && !session.isExpired;
  }
}

/// ============================================================
/// PROVIDERS
/// ============================================================

/// Current OTP session state provider.
final otpSessionProvider =
    NotifierProvider<OtpSessionController, OtpSession?>(
  OtpSessionController.new,
);
