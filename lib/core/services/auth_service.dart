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
///   - Create profile via Supabase Edge Function
///   - Handle auth errors: invalid OTP, expired OTP, network failures
///   - Expose reactive auth state via stream
///   - Confirm OTP was sent successfully
///
/// ❌ Does NOT:
///   - Contain profile/business logic
///   - Decide what happens after auth
///   - Manage onboarding state
///   - Route navigation
///   - Write directly to the database
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

/// Result of a profile creation operation via Edge Function
class ProfileResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? profile;
  const ProfileResult({required this.success, this.error, this.profile});
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
  /// CREATE PROFILE (Edge Function)
  /// ============================================================
  ///
  /// Invokes the `create-profile` Edge Function to create a user
  /// profile. The backend derives auth_user_id, id, created_at,
  /// updated_at, and created_by automatically.
  ///
  /// Returns a [ProfileResult] with the created profile on success.
  /// ============================================================
  Future<ProfileResult> createProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String countryId,
    required String phone,
    String? level2LocationId,
    String? level3LocationId,
    String? level4LocationId,
    String? level5LocationId,
    String? level6LocationId,
    String? level7LocationId,
  }) async {
    try {
      final body = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'country_id': countryId,
        'phone': phone,
        'is_phone_verified': true,
      };

      if (middleName != null && middleName.isNotEmpty) {
        body['middle_name'] = middleName;
      }
      if (level2LocationId != null) body['level_2_location_id'] = level2LocationId;
      if (level3LocationId != null) body['level_3_location_id'] = level3LocationId;
      if (level4LocationId != null) body['level_4_location_id'] = level4LocationId;
      if (level5LocationId != null) body['level_5_location_id'] = level5LocationId;
      if (level6LocationId != null) body['level_6_location_id'] = level6LocationId;
      if (level7LocationId != null) body['level_7_location_id'] = level7LocationId;

      debugPrint('========================================');
      debugPrint('[createProfile] DIAGNOSTIC START');
      debugPrint('Project URL: ${_supabase.client.supabaseUrl}');
      debugPrint('Function: create-profile');
      debugPrint('Payload: $body');
      debugPrint('User: ${_supabase.client.auth.currentUser?.id}');
      debugPrint('Session: ${_supabase.client.auth.currentSession != null}');
      debugPrint('========================================');

      final response = await _supabase.client.functions.invoke(
        'create-profile',
        body: body,
      );

      debugPrint('[createProfile] FUNCTION INVOKE COMPLETE');
      debugPrint('[createProfile] STATUS: ${response.status}');
      debugPrint('[createProfile] DATA: ${response.data}');
      debugPrint('[createProfile] ERROR: ${response.error}');

      // Validate the response envelope (same pattern as verify-otp)
      if (response.data == null || response.data is! Map) {
        debugPrint('[createProfile] FAILED: response.data is null or not a Map');
        return const ProfileResult(
          success: false,
          error: 'Invalid response from server. Please try again.',
        );
      }

      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        final errorMsg = responseData['error']?.toString() ??
            'Failed to create profile. Please try again.';
        debugPrint('[createProfile] FAILED: success != true, error: $errorMsg');
        return ProfileResult(success: false, error: errorMsg);
      }

      final profile = responseData['data'];
      if (profile == null || profile is! Map) {
        debugPrint('[createProfile] FAILED: data field is null or not a Map');
        return const ProfileResult(
          success: false,
          error: 'Profile created but no data returned. Please try again.',
        );
      }

      debugPrint('[createProfile] SUCCESS — profile created');
      debugPrint('[createProfile] Profile data: $profile');

      return ProfileResult(
        success: true,
        profile: Map<String, dynamic>.from(profile),
      );
    } on FunctionException catch (e) {
      debugPrint('[createProfile] FunctionException: ${e.details}');
      debugPrint('[createProfile] FunctionException statusCode: ${e.statusCode}');
      return ProfileResult(
        success: false,
        error: e.details?.toString() ?? e.reasonPhrase ?? 'Unknown error',
      );
    } catch (e, st) {
      debugPrint('[createProfile] FUNCTION INVOKE EXCEPTION');
      debugPrint('[createProfile] Exception: $e');
      debugPrint('[createProfile] StackTrace: $st');
      return const ProfileResult(
        success: false,
        error: 'Network error. Please check your connection and try again.',
      );
    }
  }

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

      final normalizedPhone = _normalizePhone(phone);
      if (kDebugMode) debugPrint('OTP Request Started (normalized: $normalizedPhone)');

      // Send OTP via Edge Function
      final response = await _supabase.client.functions.invoke(
        'request-otp',
        body: {'phone': normalizedPhone},
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

      final normalizedPhone = _normalizePhone(phone);
      if (kDebugMode) debugPrint('OTP Verification Started (normalized: $normalizedPhone)');

      // Verify OTP via Edge Function
      final response = await _supabase.client.functions.invoke(
        'verify-otp',
        body: {'phone': normalizedPhone, 'token': token},
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

      // ======================================================
      // SESSION HYDRATION — FIX
      // ======================================================
      // The edge function returns session keys in snake_case.
      // `setSession` is preferred because it:
      //   1. Fetches the user via GET /user using the access token
      //   2. Persists the session locally
      //   3. Emits signedIn event
      // `recoverSession` is the fallback — it only parses JSON
      // and does NOT fetch the user from the server, so it can
      // fail silently if the session shape is incomplete.
      // ======================================================
      final sessionMap = session is Map
          ? Map<String, dynamic>.from(session)
          : null;

      final accessToken = sessionMap?['access_token'] as String?;
      final refreshToken = sessionMap?['refresh_token'] as String?;

      if (accessToken != null && refreshToken != null) {
        if (kDebugMode) {
          debugPrint('[verifyOtp] Calling setSession with tokens...');
        }
        await _supabase.client.auth.setSession(
          refreshToken,
        );
      } else {
        if (kDebugMode) {
          debugPrint('[verifyOtp] setSession tokens missing, trying recoverSession...');
        }
        final sessionJson = jsonEncode(session);
        await _supabase.client.auth.recoverSession(sessionJson);
      }

      // Allow auth state change events to settle before checking
      await Future.delayed(const Duration(milliseconds: 100));

      final recoveredSession = _supabase.client.auth.currentSession;
      final recoveredUser = _supabase.client.auth.currentUser;

      debugPrint('========== AFTER SESSION RESTORE ==========');
      debugPrint('CurrentSession exists: ${recoveredSession != null}');
      debugPrint('CurrentUser exists: ${recoveredUser != null}');
      debugPrint('User ID: ${recoveredUser?.id}');
      debugPrint('Access Token exists: ${recoveredSession?.accessToken != null}');
      debugPrint('Refresh Token exists: ${recoveredSession?.refreshToken != null}');
      debugPrint('=========================================');

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
  /// PHONE NORMALIZATION
  /// ============================================================
  /// Guarantees a single leading '+' followed by digits only,
  /// suitable for E.164 validation.
  static String _normalizePhone(String phone) {
    final digitsOnly = phone
        .trim()
        .replaceFirst(RegExp(r'^\++'), '')
        .replaceAll(RegExp(r'[^\d]'), '');
    return '+$digitsOnly';
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