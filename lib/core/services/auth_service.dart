/// ============================================================
/// AUTH SERVICE — Single reusable authentication service
/// ============================================================
///
/// 🧠 ROLE:
///   Centralized authentication service wrapping Supabase Auth.
///   This is the ONLY service that should handle auth operations.
///
/// ✅ RESPONSIBILITIES:
///   - Send OTP via SMS (phone only) via Supabase Edge Function
///   - Verify OTP via Supabase Edge Function
///   - Handle auth errors: invalid OTP, expired OTP, network failures
///   - Expose reactive auth state via stream
///   - Confirm OTP was sent successfully
///
/// ❌ Does NOT:
///   - Contain profile/business logic
///   - Decide what happens after auth
///   - Manage onboarding state
///   - Route navigation
/// ============================================================
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/services/supabase_service.dart';

/// Result of an OTP send operation
class OtpSendResult {
  final bool success;
  final String? error;
  /// Whether Supabase confirmed the OTP was dispatched (no exception)
  final bool confirmed;
  const OtpSendResult({required this.success, this.error, this.confirmed = false});
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
  /// SEND OTP (Phone only)
  /// ============================================================
  ///
  /// Sends a one-time password to the user's phone via SMS.
  /// This is the ONLY OTP delivery method.
  ///
  /// [phone] - Phone number for SMS OTP
  ///
  /// Returns an [OtpSendResult] indicating success or failure.
  /// The [confirmed] flag is true when Supabase dispatched the OTP.
  /// ============================================================
  Future<OtpSendResult> sendOtp({
    String? email,
    String? phone,
  }) async {
    try {
      if (phone == null || phone.trim().isEmpty) {
        return const OtpSendResult(
          success: false,
          error: 'Please enter your phone number.',
        );
      }

                              if (kDebugMode) debugPrint('OTP Request Started');

      // Send OTP via Edge Function
      final response = await _supabase.client.functions.invoke(
        'request-otp',
        body: {'phone': phone},
      );

      // Check the response payload for application-level errors
      if (response.data != null && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data['error'] != null) {
          final errorMsg = data['error'].toString();
          if (kDebugMode) debugPrint('OTP Request Error (in data): $errorMsg');
          return OtpSendResult(
            success: false,
            error: _mapEdgeFunctionError(errorMsg),
          );
        }
      }

      if (kDebugMode) debugPrint('OTP Request Success');

      return const OtpSendResult(
        success: true,
        confirmed: true,
      );
    } on FunctionException catch (e) {
      if (kDebugMode) debugPrint('OTP Request FunctionException: ${e.details}');
      return OtpSendResult(
        success: false,
        error: _mapEdgeFunctionError(e.details?.toString() ?? e.reasonPhrase ?? 'Unknown error'),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('OTP Request Exception: $e');
      return const OtpSendResult(
        success: false,
        error: 'Network error. Please check your connection and try again.',
      );
    }
  }

    /// ============================================================
  /// VERIFY OTP (Phone only)
  /// ============================================================
  ///
  /// Verifies the OTP token sent to the user's phone.
  ///
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
      if (phone == null || phone.trim().isEmpty) {
        return const OtpVerifyResult(
          success: false,
          error: 'Please provide your phone number.',
        );
      }

                        if (kDebugMode) debugPrint('OTP Verification Started');

      // Verify OTP via Edge Function
      final response = await _supabase.client.functions.invoke(
        'verify-otp',
        body: {'phone': phone, 'token': token},
      );

      // Validate the response envelope from the Edge Function
            final responseData = response.data;
            if (kDebugMode) {
              debugPrint('[verifyOtp] Raw response: $responseData');
            }

            if (responseData == null || responseData is! Map) {
              return const OtpVerifyResult(
                success: false,
                error: 'Invalid verification response. Please try again.',
              );
            }

            // Validate success flag
            final successFlag = responseData['success'] == true;
            if (kDebugMode) {
              debugPrint('[verifyOtp] success flag: $successFlag');
            }

            if (!successFlag) {
              String errorMsg = 'Invalid verification code. Please try again.';
              if (responseData['error'] != null) {
                errorMsg = _mapEdgeFunctionError(responseData['error'].toString());
              }
              return OtpVerifyResult(success: false, error: errorMsg);
            }

            // Read nested data object
            final data = responseData['data'];
            final session = data is Map ? data['session'] : null;
            final userData = data is Map ? data['user'] : null;

            if (kDebugMode) {
              debugPrint('[verifyOtp] data.session exists: ${session != null}');
              debugPrint('[verifyOtp] data.user exists: ${userData != null}');
            }

            if (session == null) {
              return const OtpVerifyResult(
                success: false,
                error: 'Invalid verification code. Please try again.',
              );
            }

            if (kDebugMode) debugPrint('OTP Verification Success');

            // Serialize the session to JSON and recover it into the SDK
                        final sessionJson = jsonEncode(session);
                        await _supabase.client.auth.recoverSession(sessionJson);

                        debugPrint('========== AFTER recoverSession ==========');
debugPrint('CurrentSession: ${_supabase.client.auth.currentSession}');
debugPrint('CurrentUser: ${_supabase.client.auth.currentUser}');
debugPrint('CurrentUserId: ${_supabase.client.auth.currentUser?.id}');
debugPrint('AccessToken exists: ${_supabase.client.auth.currentSession?.accessToken != null}');
debugPrint('RefreshToken exists: ${_supabase.client.auth.currentSession?.refreshToken != null}');
debugPrint('==========================================');

                        // Listen for auth state change events after recoverSession
                        _supabase.client.auth.onAuthStateChange.listen((event) {
                          debugPrint(
                            'AUTH EVENT -> ${event.event} '
                            'user=${event.session?.user.id}',
                          );
                        });

                        // Verify that the session was actually established
            if (_supabase.currentUser == null) {
              if (kDebugMode) debugPrint('[verifyOtp] Session Established - FAILED: currentUser is null');
              return const OtpVerifyResult(
                success: false,
                error: 'Session could not be established. Please try again.',
              );
            }

            if (kDebugMode) {
              debugPrint('[verifyOtp] Session Established - currentUser exists: ${_supabase.currentUser != null}');
              debugPrint('Authentication Complete');
            }

            final user = _supabase.currentUser;
            return OtpVerifyResult(
              success: true,
              userId: user?.id,
            );
    } on FunctionException catch (e) {
      if (kDebugMode) debugPrint('OTP Verification FunctionException: ${e.details}');
      return OtpVerifyResult(
        success: false,
        error: _mapEdgeFunctionError(e.details?.toString() ?? e.reasonPhrase ?? 'Unknown error'),
      );
    } on AuthException catch (e) {
      if (kDebugMode) debugPrint('AuthException during verification: ${e.message}');
      return OtpVerifyResult(success: false, error: _mapAuthError(e));
    } catch (e) {
      if (kDebugMode) debugPrint('Unexpected exception during verification: $e');
      return const OtpVerifyResult(
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

  /// Map Edge Function error messages to user-friendly text
  String _mapEdgeFunctionError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid') && lower.contains('otp')) {
      return 'Invalid verification code. Please try again.';
    }
    if (lower.contains('expired')) {
      return 'This code has expired. Please request a new one.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('phone') && lower.contains('invalid')) {
      return 'Invalid phone number. Use format: +2547XXXXXXXX.';
    }
    if (lower.contains('not found')) {
      return 'Account not found. Please check your phone number.';
    }
    return message;
  }

  /// Map Supabase Auth SDK error messages to user-friendly text
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
      return 'Account not found. Please check your phone number.';
    }
    if (message.contains('phone') && message.contains('invalid')) {
      return 'Invalid phone number. Use format: +2547XXXXXXXX.';
    }
    // Default: return the original message (safe for display)
    return e.message;
  }
}