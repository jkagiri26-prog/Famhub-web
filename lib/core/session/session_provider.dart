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
///   - Load/save selected roles from local storage
///   - Provide session initialization status
///
/// ❌ Does NOT:
///   - Contain widget logic
///   - Know about routing or navigation
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/session/app_session.dart';

/// ============================================================
/// SESSION CONTROLLER
/// ============================================================
class SessionController extends Notifier<AppSession> {
  @override
  AppSession build() {
    return const UnauthenticatedSession();
  }

  /// Initialize the session from Supabase + local storage.
  /// Returns the determined status.
  Future<SessionStatus> initialize() async {
    try {
      // Check Supabase current session
      final supabase = SupabaseService.instance;
      final session = supabase.currentSession;
      final user = supabase.currentUser;

      if (session != null && user != null) {
        // Load saved roles from preferences
        final prefs = await SharedPreferences.getInstance();
        final savedRoles = prefs.getStringList('user_roles') ?? [];
        final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

        state = AuthenticatedSession(
          userId: user.id,
          displayName: user.email ?? user.id ?? 'User',
          selectedRoles: savedRoles,
          hasCompletedOnboarding: onboardingDone,
        );

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

  /// Activate guest/demo mode
  void startGuestSession() {
    state = const GuestSession();
  }

  /// Sign in with email/password
  Future<bool> signIn({required String email, required String password}) async {
    try {
      final supabase = SupabaseService.instance;
      final response = await supabase.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        final savedRoles = prefs.getStringList('user_roles') ?? [];
        final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

        state = AuthenticatedSession(
          userId: response.user!.id,
          displayName: response.user!.email ?? 'User',
          selectedRoles: savedRoles,
          hasCompletedOnboarding: onboardingDone,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Create account with email/password
  Future<bool> signUp({required String email, required String password}) async {
    try {
      final supabase = SupabaseService.instance;
      final response = await supabase.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        state = AuthenticatedSession(
          userId: response.user!.id,
          displayName: email,
          selectedRoles: const [],
          hasCompletedOnboarding: false,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      final supabase = SupabaseService.instance;
      await supabase.signOut();
    } catch (_) {
      // Continue with local sign out
    }

    state = const UnauthenticatedSession();
  }

  /// Save selected roles (capabilities) for the user
  Future<void> saveRoles(List<String> roles) async {
    final current = state;
    if (current is AuthenticatedSession) {
      state = current.copyWith(
        selectedRoles: roles,
        hasCompletedOnboarding: true,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_roles', roles);
      await prefs.setBool('onboarding_complete', true);
    }
  }

  /// Complete onboarding for guest user (roles only stored in memory)
  void completeGuestOnboarding(List<String> roles) {
    final current = state;
    if (current is GuestSession) {
      state = current.copyWith(
        selectedRoles: roles,
        hasCompletedOnboarding: true,
      );
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

/// Whether the user is a guest
final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).isGuest;
});

/// Whether onboarding (role selection) is complete
final hasOnboardingCompletedProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).hasCompletedOnboarding;
});

