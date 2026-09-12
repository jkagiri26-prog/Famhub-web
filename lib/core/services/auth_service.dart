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

/// Result of a workspace selection operation via Edge Function
class WorkspaceSelectionResult {
  final bool success;
  final String? error;

  /// The persisted workspace IDs (system.workspaces.id values).
  final List<String> workspaceIds;

  /// The default workspace ID chosen by the backend.
  final String? defaultWorkspaceId;

  /// Raw workspace records returned by the backend (selected workspaces).
  final List<Map<String, dynamic>> workspaces;

  /// The authoritative profile row returned by the backend (may be null if the
  /// function does not echo it; the caller can re-fetch from users.profiles).
  final Map<String, dynamic>? profile;

  // ── Canonical entity context (from users.complete_workspace_selection) ──
  /// users.profiles.id
  final String? profileId;

  /// core.entities.id (the personal operating entity ensured by the backend)
  final String? entityId;

  /// core.user_roles.id
  final String? roleId;

  /// core.entity_context_sessions.active_mode
  final String? activeMode;

  /// commerce.business_profiles.id (nullable)
  final String? businessProfileId;

  const WorkspaceSelectionResult({
    required this.success,
    this.error,
    this.workspaceIds = const [],
    this.defaultWorkspaceId,
    this.workspaces = const [],
    this.profile,
    this.profileId,
    this.entityId,
    this.roleId,
    this.activeMode,
    this.businessProfileId,
  });
}

/// Result of adding a workspace membership via the authenticated RPC
/// `users.add_workspace_membership`.
class WorkspaceMembershipResult {
  final bool success;
  final String? error;

  /// True when the backend reported the membership already existed.
  /// This is treated as success by callers.
  final bool alreadyExists;

  const WorkspaceMembershipResult({
    required this.success,
    this.error,
    this.alreadyExists = false,
  });
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
      debugPrint('[createProfile] FunctionException status: ${e.status}');
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
  /// SELECT WORKSPACES (Edge Function)
  /// ============================================================
  ///
  /// Invokes the `select-workspaces` Edge Function with the selected
  /// system.workspaces.id values. The backend:
  ///   - authenticates the user from the Bearer token
  ///   - verifies the workspace IDs
  ///   - saves selections into users.user_workspaces
  ///   - marks the first selected workspace as default
  ///   - updates users.profiles.is_complete
  ///   - updates users.profiles.current_workspace_id
  ///   - returns the selected workspace data + the default workspace
  ///
  /// Returns a [WorkspaceSelectionResult] on success.
  /// ============================================================
  Future<WorkspaceSelectionResult> selectWorkspaces({
    required List<String> workspaceIds,
  }) async {
    if (workspaceIds.isEmpty) {
      return const WorkspaceSelectionResult(
        success: false,
        error: 'Select at least one workspace.',
      );
    }

    try {
      debugPrint('========================================');
      debugPrint('[selectWorkspaces] DIAGNOSTIC START');
      debugPrint('Function: select-workspaces');
      debugPrint('Payload: $workspaceIds');
      debugPrint('Session: ${_supabase.client.auth.currentSession != null}');
      debugPrint('========================================');

      final response = await _supabase.client.functions.invoke(
        'select-workspaces',
        body: {'workspace_ids': workspaceIds},
      );

      debugPrint('[selectWorkspaces] FUNCTION INVOKE COMPLETE');
      debugPrint('[selectWorkspaces] STATUS: ${response.status}');
      debugPrint('[selectWorkspaces] DATA: ${response.data}');

      // Validate the response envelope (same pattern as create-profile).
      if (response.data == null || response.data is! Map) {
        return const WorkspaceSelectionResult(
          success: false,
          error: 'Invalid response from server. Please try again.',
        );
      }

      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        final errorMsg = responseData['error']?.toString() ??
            'Failed to save workspaces. Please try again.';
        return WorkspaceSelectionResult(success: false, error: errorMsg);
      }

      // ── Parse the payload defensively ──
      // The backend returns the selected workspace data and the default
      // workspace. We tolerate several envelope shapes so the frontend
      // never breaks when the backend adds fields.
      final data = responseData['data'];
      if (data is! Map) {
        return const WorkspaceSelectionResult(
          success: false,
          error: 'Invalid response from server. Please try again.',
        );
      }

      final dataMap = Map<String, dynamic>.from(data);

      // The Edge Function must explicitly confirm that onboarding can
      // proceed to the dashboard. HTTP 200 alone is not enough.
      if (dataMap['next_step']?.toString() != 'dashboard') {
        debugPrint('[selectWorkspaces] Unexpected next_step: '
            '${dataMap['next_step']}');
        return const WorkspaceSelectionResult(
          success: false,
          error: 'Unexpected response from server. Please try again.',
        );
      }

      List<Map<String, dynamic>> workspaces = [];
      String? defaultWorkspaceId;
      Map<String, dynamic>? profile;

      // Collect workspace records from `workspaces` / `selected_workspaces`.
      final rawWorkspaces = dataMap['workspaces'] ??
          dataMap['selected_workspaces'] ??
          dataMap['data'];
      if (rawWorkspaces is List) {
        workspaces = rawWorkspaces
            .whereType<Map>()
            .map((w) => Map<String, dynamic>.from(w))
            .toList();
      }

      // Authoritative profile row echoed by the backend, if any.
      final rawProfile = dataMap['profile'];
      if (rawProfile is Map) {
        profile = Map<String, dynamic>.from(rawProfile);
      }

      // Default workspace: explicit id, nested object, or is_default flag.
      final explicitDefault = dataMap['default_workspace_id']?.toString() ??
          dataMap['current_workspace_id']?.toString();
      if (explicitDefault != null && explicitDefault.isNotEmpty) {
        defaultWorkspaceId = explicitDefault;
      } else {
        final defaultWs = dataMap['default_workspace'];
        if (defaultWs is Map) {
          defaultWorkspaceId = defaultWs['id']?.toString();
        }
      }

      // Fall back to the `is_default` flag when no explicit default exists.
      if (defaultWorkspaceId == null) {
        for (final ws in workspaces) {
          if (ws['is_default'] == true) {
            defaultWorkspaceId = ws['id']?.toString();
            break;
          }
        }
      }

      final persistedIds = workspaces
          .map((w) => w['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      debugPrint('[selectWorkspaces] SUCCESS');
      debugPrint('[selectWorkspaces] Workspaces: $persistedIds');
      debugPrint('[selectWorkspaces] Default: $defaultWorkspaceId');

      // ── SILENT ENTITY BOOTSTRAP ──
      // After the existing workspace selection succeeds, complete the
      // selection server-side. The backend ensures/reuses the personal
      // operating entity, creates the workspace↔entity mapping, and
      // activates the canonical entity context. For first-time onboarding
      // the entity/role/business-profile params are null (backend-derived).
      final targetWorkspaceId = defaultWorkspaceId ??
          (persistedIds.isNotEmpty
              ? persistedIds.first
              : (workspaceIds.isNotEmpty ? workspaceIds.first : null));

      Map<String, dynamic>? entityContext;
      if (targetWorkspaceId != null && targetWorkspaceId.isNotEmpty) {
        entityContext =
            await _completeWorkspaceSelectionEntityContext(targetWorkspaceId);
      }

      return WorkspaceSelectionResult(
        success: true,
        workspaceIds: persistedIds.isNotEmpty ? persistedIds : workspaceIds,
        defaultWorkspaceId: defaultWorkspaceId,
        workspaces: workspaces,
        profile: profile,
        profileId: entityContext?['profile_id']?.toString(),
        entityId: entityContext?['entity_id']?.toString(),
        roleId: entityContext?['role_id']?.toString(),
        activeMode: entityContext?['active_mode']?.toString(),
        businessProfileId: entityContext?['business_profile_id']?.toString(),
      );
    } on FunctionException catch (e) {
      debugPrint('[selectWorkspaces] FunctionException: ${e.details}');
      return WorkspaceSelectionResult(
        success: false,
        error: e.details?.toString() ?? e.reasonPhrase ?? 'Unknown error',
      );
    } catch (e, st) {
      debugPrint('[selectWorkspaces] FUNCTION INVOKE EXCEPTION');
      debugPrint('[selectWorkspaces] Exception: $e');
      debugPrint('[selectWorkspaces] StackTrace: $st');
      return const WorkspaceSelectionResult(
        success: false,
        error: 'Network error. Please check your connection and try again.',
      );
    }
  }

  /// ============================================================
  /// COMPLETE WORKSPACE SELECTION (Entity Bootstrap RPC)
  /// ============================================================
  ///
  /// Invokes `users.complete_workspace_selection(p_workspace_id,
  /// p_entity_id, p_role_id, p_business_profile_id)`.
  ///
  /// For first-time onboarding only the workspace id is supplied; the
  /// entity/role/business-profile params are null and resolved/created
  /// server-side. Returns the single returned row, or null when the RPC
  /// is unavailable — onboarding is NOT blocked (the existing UX is
  /// preserved), but the context simply stays unavailable.
  Future<Map<String, dynamic>?> _completeWorkspaceSelectionEntityContext(
    String workspaceId,
  ) async {
    try {
      final response = await _supabase.client
          .schema('users')
          .rpc('complete_workspace_selection', params: {
        'p_workspace_id': workspaceId,
        'p_entity_id': null,
        'p_role_id': null,
        'p_business_profile_id': null,
      });

      // Function returns a single table row: PostgREST yields a List.
      if (response is List && response.isNotEmpty) {
        final first = response.first;
        if (first is Map) return Map<String, dynamic>.from(first);
      }
      if (response is Map) return Map<String, dynamic>.from(response);
      debugPrint('[complete_workspace_selection] Unexpected response: $response');
      return null;
    } catch (e) {
      debugPrint('[complete_workspace_selection] failed: $e');
      return null;
    }
  }

  /// ============================================================
  /// GET AVAILABLE WORKSPACE CONTEXTS
  /// ============================================================
  ///
  /// Invokes `users.get_available_workspace_contexts()` (no parameters).
  /// Returns every workspace/entity context available to the
  /// authenticated user. Each row contains (at least):
  ///   workspace_id, entity_id, role_id, active_mode, business_profile_id
  /// plus the backend-provided display-name fields.
  ///
  /// Throws on failure so the caller can distinguish an empty result
  /// from a load error.
  Future<List<Map<String, dynamic>>> getAvailableWorkspaceContexts() async {
    Object? response;
    try {
      response = await _supabase.client
          .schema('users')
          .rpc('get_available_workspace_contexts');
    } catch (e, st) {
      // TEMPORARY DIAGNOSTIC (remove after the Farmer-context regression):
      // surface the Supabase error object. No tokens/credentials are logged.
      debugPrint('[get_available_workspace_contexts] ERROR '
          'type=${e.runtimeType} error=$e');
      debugPrintStack(
        stackTrace: st,
        label: '[get_available_workspace_contexts]',
        maxFrames: 6,
      );
      rethrow;
    }

    final rows = _asContextRows(response);

    // TEMPORARY DIAGNOSTIC (remove after the Farmer-context regression):
    // expose exactly what the backend returns so the zero-context case is
    // identified from data, not guessed. IDs only — no personal data.
    debugPrint('[get_available_workspace_contexts] rawType=${response.runtimeType} '
        'count=${rows.length}');
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      debugPrint('[get_available_workspace_contexts] row[$i] '
          'workspace_id=${row['workspace_id']} '
          'entity_id=${row['entity_id']} '
          'role_id=${row['role_id']} '
          'active_mode=${row['active_mode']} '
          'business_profile_id=${row['business_profile_id']}');
    }

    return rows;
  }

  List<Map<String, dynamic>> _asContextRows(Object? response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }
    if (response is Map) return [Map<String, dynamic>.from(response)];
    return const [];
  }

  /// ============================================================
  /// ACTIVATE WORKSPACE CONTEXT
  /// ============================================================
  ///
  /// Invokes
  /// `users.activate_workspace_context(p_workspace_id, p_entity_id,
  ///  p_role_id, p_business_profile_id)`.
  ///
  /// Returns the activated canonical context row, or null on failure.
  /// The client NEVER writes to core.entity_context_sessions directly.
  Future<Map<String, dynamic>?> activateWorkspaceContext({
    required String workspaceId,
    String? entityId,
    String? roleId,
    String? businessProfileId,
  }) async {
    // TEMPORARY DIAGNOSTIC (remove after the Farmer-context regression).
    debugPrint('[activate_workspace_context] REQUEST '
        'p_workspace_id=$workspaceId '
        'p_entity_id=$entityId '
        'p_role_id=$roleId '
        'p_business_profile_id=$businessProfileId');

    try {
      final response = await _supabase.client
          .schema('users')
          .rpc('activate_workspace_context', params: {
        'p_workspace_id': workspaceId,
        'p_entity_id': entityId,
        'p_role_id': roleId,
        'p_business_profile_id': businessProfileId,
      });

      final row = _firstContextRow(response);
      if (row != null) {
        debugPrint('[activate_workspace_context] RESPONSE row '
            'workspace_id=${row['workspace_id']} '
            'entity_id=${row['entity_id']} '
            'role_id=${row['role_id']} '
            'active_mode=${row['active_mode']} '
            'business_profile_id=${row['business_profile_id']}');
        return row;
      }

      debugPrint('[activate_workspace_context] RESPONSE empty/void: '
          'rawType=${response.runtimeType} value=$response');
      return null;
    } catch (e, st) {
      // TEMPORARY DIAGNOSTIC (remove after the Farmer-context regression).
      debugPrint('[activate_workspace_context] ERROR '
          'type=${e.runtimeType} error=$e');
      debugPrintStack(
        stackTrace: st,
        label: '[activate_workspace_context]',
        maxFrames: 6,
      );
      return null;
    }
  }

  Map<String, dynamic>? _firstContextRow(Object? response) {
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    return null;
  }

  /// ============================================================
  /// ADD WORKSPACE MEMBERSHIP (Authenticated RPC)
  /// ============================================================
  ///
  /// TEMPORARY / TEST PATH.
  ///
  /// Invokes `users.add_workspace_membership(p_workspace_id,
  /// p_make_default)` using the EXISTING authenticated Supabase client.
  /// The auth user id is derived from the current Supabase session by the
  /// backend — it is NEVER passed from the client.
  ///
  /// This does NOT create an entity, entity membership, entity role, or
  /// Admin permissions, and it does NOT change the current/default
  /// workspace when [makeDefault] is false.
  ///
  /// Returns a [WorkspaceMembershipResult]. A backend "already exists"
  /// response is reported as success.
  Future<WorkspaceMembershipResult> addWorkspaceMembership({
    required String workspaceId,
    bool makeDefault = false,
  }) async {
    if (!isAuthenticated) {
      return const WorkspaceMembershipResult(
        success: false,
        error: 'authentication required',
      );
    }

    try {
      final response = await _supabase.client.schema('users').rpc(
        'add_workspace_membership',
        params: {
          'p_workspace_id': workspaceId,
          'p_make_default': makeDefault,
        },
      );

      debugPrint('[addWorkspaceMembership] response: $response');
      return WorkspaceMembershipResult(
        success: true,
        alreadyExists: _membershipAlreadyExists(response),
      );
    } on PostgrestException catch (e) {
      debugPrint('[addWorkspaceMembership] PostgrestException: '
          'code=${e.code} message=${e.message} details=${e.details}');
      final combined =
          '${e.message} ${e.details ?? ''}'.toLowerCase();
      if (combined.contains('authentication required') ||
          combined.contains('not authenticated')) {
        return const WorkspaceMembershipResult(
          success: false,
          error: 'authentication required',
        );
      }
      if (_membershipAlreadyExists(e) || e.code == '23505') {
        return const WorkspaceMembershipResult(
          success: true,
          alreadyExists: true,
        );
      }
      return WorkspaceMembershipResult(
        success: false,
        error: e.message,
      );
    } catch (e, st) {
      debugPrint('[addWorkspaceMembership] exception: $e');
      debugPrintStack(
        stackTrace: st,
        label: '[addWorkspaceMembership]',
        maxFrames: 6,
      );
      return WorkspaceMembershipResult(success: false, error: e.toString());
    }
  }

  /// Detect an "already exists" signal from an RPC response or error.
  bool _membershipAlreadyExists(Object? response) {
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      if (map['already_exists'] == true ||
          map['alreadyExists'] == true) {
        return true;
      }
      final status = (map['status'] ??
              map['message'] ??
              map['error'] ??
              '')
          .toString()
          .toLowerCase();
      if (status.contains('already')) return true;
    }
    if (response is List) {
      for (final item in response) {
        if (_membershipAlreadyExists(item)) return true;
      }
    }
    if (response is PostgrestException) {
      final combined =
          '${response.message} ${response.details ?? ''}'.toLowerCase();
      if (combined.contains('already') ||
          combined.contains('duplicate') ||
          response.code == '23505') {
        return true;
      }
    }
    return false;
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