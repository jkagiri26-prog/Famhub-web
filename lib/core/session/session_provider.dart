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
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/services/auth_service.dart';
import 'package:famhub_app/core/session/app_session.dart';

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
  /// Called after first-time authentication when no profile exists.
  /// Uses core.locations UUIDs for county_id, sub_county_id, ward_id.
  ///
  /// [lastName] defaults to [firstName] if empty, because the backend
  /// profiles.last_name column is NOT NULL.
  Future<bool> createProfile({
    required String firstName,
    String? middleName,
    String? lastName,
    String? countyId,
    String? subCountyId,
    String? wardId,
  }) async {
    final current = state;
    if (current is! AuthenticatedSession) return false;

    try {
      // Backend contract: auth_user_id and id are derived server-side
      // from the JWT/session. The client NEVER sends user identity fields.
      final data = <String, dynamic>{
        'first_name': firstName.trim(),
        'middle_name': (middleName != null && middleName.trim().isNotEmpty)
            ? middleName.trim()
            : null,
        'last_name': (lastName != null && lastName.trim().isNotEmpty)
            ? lastName.trim()
            : firstName.trim(), // fallback: use first name as last name
        'county_id': countyId,
        'sub_county_id': subCountyId,
        'ward_id': wardId,
      };

      await SupabaseService.instance
          .from('profiles', schema: 'users')
          .insert(data);

      // Build display name
      final displayParts = <String>[firstName.trim()];
      if (middleName != null && middleName.trim().isNotEmpty) {
        displayParts.add(middleName.trim());
      }
      final last = (lastName != null && lastName.trim().isNotEmpty)
          ? lastName.trim()
          : firstName.trim();
      displayParts.add(last);

      state = current.copyWith(
        displayName: displayParts.join(' '),
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