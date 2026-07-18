/// ============================================================
/// APP SESSION — Three-state session interface
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/session/ = session management layer
///
/// ✅ Responsibilities:
///   - Define the session interface
///   - Distinguish unauthenticated vs authenticated sessions
///   - Provide user identity information
///   - Manage selected stakeholder roles (capabilities)
///
/// ❌ Does NOT:
///   - Contain widget logic
///   - Know about UI or routing
///   - Import demo or Supabase repositories directly
/// ============================================================
library;

/// Enum representing session initialization status
enum SessionStatus {
  /// Initializing (splash screen should show)
  initializing,

  /// Ready — no session (welcome screen should show)
  unauthenticated,

  /// Ready — authenticated (dashboard should show)
  authenticated,
}

/// Abstract session interface representing the current user's session state.
///
/// The UI switches data sources based on session type
/// but never needs to know whether data comes from sample or real repositories.
abstract class AppSession {
  /// Current session status (initialization state machine)
  SessionStatus get status;

  /// Whether this is an authenticated (real) user
  bool get isAuthenticated;

  /// The display name of the user
  String get displayName;

  /// The unique user ID (null for unauthenticated)
  String? get userId;

  /// Stakeholder roles selected by the user during onboarding.
  /// These personalize the platform experience.
  /// Multiple roles can be selected simultaneously.
  List<String> get selectedRoles;

  /// Whether the user has completed onboarding (workspace selection)
  bool get hasCompletedOnboarding;

  /// Whether the user has a profile in the profiles table
  bool get hasProfile;
}

/// Session state for unauthenticated users.
/// This is the default state before session initialization completes.
/// Unauthenticated users can still browse the FAMHUB Home ecosystem.
class UnauthenticatedSession implements AppSession {
  const UnauthenticatedSession();

  @override
  SessionStatus get status => SessionStatus.unauthenticated;
  @override
  bool get isAuthenticated => false;
  @override
  String get displayName => '';
  @override
  String? get userId => null;
  @override
  List<String> get selectedRoles => const [];
  @override
  bool get hasCompletedOnboarding => false;
  @override
  bool get hasProfile => false;
}

/// Session for authenticated users with real Supabase identity.
class AuthenticatedSession implements AppSession {
  @override
  final String? userId;
  @override
  final String displayName;
  @override
  final List<String> selectedRoles;
  @override
  final bool hasCompletedOnboarding;
  @override
  final bool hasProfile;

  const AuthenticatedSession({
    this.userId,
    required this.displayName,
    this.selectedRoles = const [],
    this.hasCompletedOnboarding = false,
    this.hasProfile = false,
  });

  @override
  SessionStatus get status => SessionStatus.authenticated;
  @override
  bool get isAuthenticated => true;

  /// Create a copy with updated fields.
  AuthenticatedSession copyWith({
    String? userId,
    String? displayName,
    List<String>? selectedRoles,
    bool? hasCompletedOnboarding,
    bool? hasProfile,
  }) {
    return AuthenticatedSession(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      selectedRoles: selectedRoles ?? this.selectedRoles,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      hasProfile: hasProfile ?? this.hasProfile,
    );
  }
}

