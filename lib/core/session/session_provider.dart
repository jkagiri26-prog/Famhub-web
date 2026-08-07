/// ============================================================
/// SESSION PROVIDER — Application-wide session state
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/session/ = session management layer
///
/// ✅ Responsibilities:
///   - Provide the current AppSession via Riverpod
///   - React to Supabase auth state changes
///   - Check for user profile on every session init
///   - Load/save selected workspaces from local storage
///   - Provide session initialization status
///
/// ❌ Does NOT:
///   - Contain widget logic
///   - Know about routing or navigation
///   - Write directly to the database (uses AuthService)
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/services/auth_service.dart';
import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/features/profile/application/providers/profile_location_provider.dart';

/// ============================================================
/// SESSION CONTROLLER
/// ============================================================
class SessionController extends Notifier<AppSession> {
  final AuthService _authService = AuthService();

  @override
  AppSession build() {
    return const UnauthenticatedSession();
  }

  /// Initialize the session from Supabase.
  /// Checks for existing Supabase session and user profile.
  /// Returns the determined status.
  Future<SessionStatus> initialize() async {
    try {
      // Check Supabase current session
      final supabase = SupabaseService.instance;
      final session = supabase.currentSession;
      final user = supabase.currentUser;

      if (session != null && user != null) {
        // ── Profile Detection ──
        final profileExists = await _checkProfileExists(user.id);

        if (profileExists) {
          // Load profile data
          final displayName = (await _loadDisplayName(user.id)) ??
              user.email ??
              'User';

          // Load saved workspaces from preferences
          final prefs = await SharedPreferences.getInstance();
          final savedWorkspaces =
              prefs.getStringList('user_workspaces') ?? [];
          final onboardingDone =
              prefs.getBool('onboarding_complete') ?? false;

          state = AuthenticatedSession(
            userId: user.id,
            displayName: displayName,
            selectedRoles: savedWorkspaces,
            hasCompletedOnboarding: onboardingDone,
            hasProfile: true,
          );
        } else {
          // Authenticated but no profile exists yet
          state = AuthenticatedSession(
            userId: user.id,
            displayName: user.email ?? 'User',
            selectedRoles: const [],
            hasCompletedOnboarding: false,
            hasProfile: false,
          );
        }

        return SessionStatus.authenticated;
      }

      // No active session — unauthenticated
      state = const UnauthenticatedSession();
      return SessionStatus.unauthenticated;
    } catch (e) {
      // On error, default to unauthenticated
      state = const UnauthenticatedSession();
      return SessionStatus.unauthenticated;
    }
  }

  /// Check whether a user profile exists in Supabase.
  Future<bool> _checkProfileExists(String userId) async {
    try {
      final response = await SupabaseService.instance
          .from('profiles', schema: 'users')
          .select('id')
          .eq('auth_user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      // If table doesn't exist or error, assume no profile
      return false;
    }
  }

  /// Load the user's display name from their profile.
  Future<String?> _loadDisplayName(String userId) async {
    try {
      final response = await SupabaseService.instance
          .from('profiles', schema: 'users')
          .select('first_name, last_name, middle_name')
          .eq('auth_user_id', userId)
          .maybeSingle();
      if (response != null) {
        final first = response['first_name'] as String?;
        final last = response['last_name'] as String?;
        final middle = response['middle_name'] as String?;
        // Build display name: first + middle + last
        final parts = <String>[];
        if (first != null && first.isNotEmpty) parts.add(first);
        if (middle != null && middle.isNotEmpty) parts.add(middle);
        if (last != null && last.isNotEmpty) parts.add(last);
        if (parts.isNotEmpty) return parts.join(' ');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Refresh session state (called after auth operations complete).
  Future<SessionStatus> refresh() async {
    return initialize();
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    state = const UnauthenticatedSession();
  }

  /// ============================================================
  /// PROFILE MANAGEMENT
  /// ============================================================

  /// Create a profile for the authenticated user.
  /// Invokes the `create-profile` Edge Function — no direct database write.
  ///
  /// [firstName] — required first name
  /// [countryId] — country ID from OTP session
  /// [phone] — verified phone number
  /// [locationLevels] — selected geography locations
  ///
  /// Returns `true` on success, updates session state with the returned
  /// profile data.
  Future<bool> createProfile({
    required String firstName,
    required String countryId,
    required String phone,
    required List<SelectedLocationEntry> locationLevels,
  }) async {
    final current = state;
    if (current is! AuthenticatedSession) return false;

    try {
      // Map location levels to level_2…level_7 parameters
      String? level2, level3, level4, level5, level6, level7;
      for (var i = 0; i < locationLevels.length && i < 6; i++) {
        final locId = locationLevels[i].locationId;
        switch (i) {
          case 0: level2 = locId;
          case 1: level3 = locId;
          case 2: level4 = locId;
          case 3: level5 = locId;
          case 4: level6 = locId;
          case 5: level7 = locId;
        }
      }

      // Invoke the Edge Function via AuthService
      final result = await _authService.createProfile(
        firstName: firstName.trim(),
        lastName: '', // last name is optional at profile creation
        countryId: countryId,
        phone: phone,
        level2LocationId: level2,
        level3LocationId: level3,
        level4LocationId: level4,
        level5LocationId: level5,
        level6LocationId: level6,
        level7LocationId: level7,
      );

      if (!result.success) {
        return false;
      }

      // Update session state with the created profile
      // Attempt to extract display name from the returned profile
      final profile = result.profile;
      String displayName = firstName.trim();
      if (profile != null) {
        final first = profile['first_name'] as String? ?? firstName.trim();
        final middle = profile['middle_name'] as String? ?? '';
        final last = profile['last_name'] as String? ?? '';
        final parts = <String>[];
        if (first.isNotEmpty) parts.add(first);
        if (middle.isNotEmpty) parts.add(middle);
        if (last.isNotEmpty) parts.add(last);
        if (parts.isNotEmpty) displayName = parts.join(' ');
      }

      state = current.copyWith(
        displayName: displayName,
        hasProfile: true,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// ============================================================
  /// WORKSPACE SELECTION MANAGEMENT
  /// ============================================================

  /// Save selected workspaces. Marks onboarding as complete.
  Future<void> saveWorkspaces(List<String> workspaces) async {
    final current = state;
    if (current is AuthenticatedSession) {
      state = current.copyWith(
        selectedRoles: workspaces,
        hasCompletedOnboarding: true,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_workspaces', workspaces);
      await prefs.setBool('onboarding_complete', true);
    }
  }

  /// Add a workspace to the user's selection.
  Future<void> addWorkspace(String workspace) async {
    final current = state;
    if (current is AuthenticatedSession) {
      final updated = [...current.selectedRoles, workspace];
      await saveWorkspaces(updated);
    }
  }
}

/// ============================================================
/// PROVIDERS
/// ============================================================

final sessionProvider =
    NotifierProvider<SessionController, AppSession>(
  SessionController.new,
);

/// Current session status
final sessionStatusProvider = Provider<SessionStatus>((ref) {
  return ref.watch(sessionProvider).status;
});

/// Whether the user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).isAuthenticated;
});

/// Whether the user has a profile
final hasProfileProvider = Provider<bool>((ref) {
  final session = ref.watch(sessionProvider);
  if (session is AuthenticatedSession) {
    return session.hasProfile;
  }
  return false;
});

/// Whether onboarding (workspace selection) is complete
final hasOnboardingCompletedProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).hasCompletedOnboarding;
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});