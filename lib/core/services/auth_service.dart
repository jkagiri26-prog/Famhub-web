/// ============================================================
/// AUTH SERVICE — Single reusable authentication service
/// ============================================================
///
/// 🧠 ROLE:
///   Centralized authentication service wrapping Supabase Auth.
///   This is the ONLY service that should handle auth operations.
///
/// ✅ RESPONSIBILITIES:
///   - Send OTP (email or SMS) via Supabase signInWithOtp()
///   - Verify OTP via Supabase verifyOTP()
///   - Handle auth errors: invalid OTP, expired OTP, network failures
///   - Expose reactive auth state via stream
///
/// ❌ Does NOT:
///   - Contain profile/business logic
///   - Decide what happens after auth
///   - Manage onboarding state
///   - Route navigation
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/services/supabase_service.dart';

/// Result of an OTP send operation
class OtpSendResult {
  final bool success;
  final String? error;
  const OtpSendResult({required this.success, this.error});
}

/// Result of an OTP verification operation
class OtpVerifyResult {
  final bool success;
  final String? error;
  final String? userId;
  const OtpVerifyResult({required this.success, this.error, this.userId});
}

/// Unified auth service for FAMHUB.
/// All auth operations go through this service.
class AuthService {
  final SupabaseService _supabase;

  AuthService({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  /// Get the current authenticated user (null if not authenticated)
  User? get currentUser => _supabase.currentUser;

  /// Whether the user is currently authenticated
  bool get isAuthenticated => _supabase.isAuthenticated;

  /// Current user ID (null if not authenticated)
  String? get currentUserId => _supabase.currentUserId;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _supabase.authStateChanges;

  /// ============================================================
  /// SEND OTP
  /// ============================================================
  ///
  /// Sends a one-time password to the user's email or phone.
  ///
  /// [email] - Email address for email OTP
  /// [phone] - Phone number for SMS OTP
  ///
  /// Returns an [OtpSendResult] indicating success or failure.
  /// ============================================================
  Future<OtpSendResult> sendOtp({
    String? email,
    String? phone,
  }) async {
    try {
      if (email != null && email.isNotEmpty) {
        await _supabase.client.auth.signInWithOtp(email: email);
      } else if (phone != null && phone.isNotEmpty) {
        await _supabase.client.auth.signInWithOtp(phone: phone);
      } else {
        return const OtpSendResult(
          success: false,
          error: 'Please provide an email or phone number.',
        );
      }

      return const OtpSendResult(success: true);
    } on AuthException catch (e) {
      return OtpSendResult(success: false, error: _mapAuthError(e));
    } catch (e) {
      return OtpSendResult(
        success: false,
        error: 'Network error. Please check your connection and try again.',
      );
    }
  }

  /// ============================================================
  /// VERIFY OTP
  /// ============================================================
  ///
  /// Verifies the OTP token sent to the user's email or phone.
  ///
  /// [email] - Email address (must match the one used in sendOtp)
  /// [phone] - Phone number (must match the one used in sendOtp)
  /// [token] - The OTP code entered by the user
  ///
  /// Returns an [OtpVerifyResult] with the user ID on success.
  /// ============================================================
  Future<OtpVerifyResult> verifyOtp({
    String? email,
    String? phone,
    required String token,
  }) async {
    try {
      if (email != null && email.isNotEmpty) {
        await _supabase.client.auth.verifyOTP(
          email: email,
          token: token,
          type: OtpType.email,
        );
      } else if (phone != null && phone.isNotEmpty) {
        await _supabase.client.auth.verifyOTP(
          phone: phone,
          token: token,
          type: OtpType.sms,
        );
      } else {
        return const OtpVerifyResult(
          success: false,
          error: 'Please provide an email or phone number.',
        );
      }

      final user = _supabase.currentUser;
      return OtpVerifyResult(
        success: true,
        userId: user?.id,
      );
    } on AuthException catch (e) {
      return OtpVerifyResult(success: false, error: _mapAuthError(e));
    } catch (e) {
      return OtpVerifyResult(
        success: false,
        error: 'Network error. Please check your connection and try again.',
      );
    }
  }

  /// ============================================================
  /// SIGN OUT
  /// ============================================================
  Future<void> signOut() async {
    await _supabase.signOut();
  }

  /// ============================================================
  /// ERROR MAPPING
  /// ============================================================
  String _mapAuthError(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid') && message.contains('otp')) {
      return 'Invalid verification code. Please try again.';
    }
    if (message.contains('expired')) {
      return 'This code has expired. Please request a new one.';
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (message.contains('network') || message.contains('timeout')) {
      return 'Network error. Please check your connection.';
    }
    if (message.contains('not found')) {
      return 'Account not found. Please check your details.';
    }
    // Default: return the original message (safe for display)
    return e.message;
  }
}