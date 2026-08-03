/// ============================================================
/// OTP SESSION STORAGE — SharedPreferences persistence
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/infrastructure/services/ = infrastructure layer
///
/// ✅ Responsibilities:
///   - Persist OTP session to SharedPreferences
///   - Load OTP session from SharedPreferences
///   - Clear OTP session data
///   - Provide a clean interface for session lifecycle management
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Know about UI or widgets
///   - Validate session expiry (delegated to OtpSession model)
/// ============================================================
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:famhub_app/features/auth/domain/models/otp_session.dart';

/// Storage keys for OTP session persistence.
class OtpSessionStorageKeys {
  static const String otpSession = 'famhub_otp_session';
}

/// Handles persistence of OTP verification sessions.
class OtpSessionStorage {
  /// Save the current OTP session to local storage.
  /// This must be called immediately after OTP is sent successfully.
  static Future<void> saveSession(OtpSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(session.toJson());
      await prefs.setString(OtpSessionStorageKeys.otpSession, json);
    } catch (e) {
      // Persistence failure is non-fatal — the user can still proceed
      // with the current in-memory session, but won't be able to recover.
    }
  }

  /// Load the persisted OTP session, if any.
  /// Returns null if no session exists or data is invalid.
  static Future<OtpSession?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(OtpSessionStorageKeys.otpSession);
      if (raw == null || raw.isEmpty) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      return OtpSession.fromJson(json);
    } catch (_) {
      // Invalid or corrupted data — treat as no session
      return null;
    }
  }

  /// Clear the persisted OTP session.
  /// Call after successful verification, expiry, or user cancellation.
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(OtpSessionStorageKeys.otpSession);
    } catch (_) {
      // Best-effort cleanup
    }
  }
}