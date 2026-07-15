/// ============================================================
/// APP SESSION — Abstract session interface
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/session/ = session management layer
///
/// ✅ Responsibilities:
///   - Define the session interface
///   - Distinguish guest vs authenticated sessions
///   - Provide user identity information
///   - Manage selected stakeholder roles (capabilities)
///
/// ❌ Does NOT:
///   - Contain widget logic
///   - Know about UI or routing
///   - Import demo or Supabase repositories directly
/// ============================================================

/// Enum representing session initialization status
enum SessionStatus {
  /// Initializing (splash screen should show)
  initializing,

  /// Ready — no session (welcome screen should show)
  unauthenticated,

  /// Ready — authenticated (dashboard should show)
  authenticated,

  /// Ready — guest mode (FAMHUB Home with demo data should show)
  guest,
}

/// Abstract session interface representing the current user's session state.
///
/// The UI switches data sources based on session type (guest vs authenticated)
/// but never needs to know whether data comes from demo or real repositories.
abstract class AppSession {
  /// Current session status (initialization state machine)
  SessionStatus get status;

  /// Whether this is an authenticated (real) user
  bool get isAuthenticated;

  /// Whether this is a guest (demo) user
  bool get isGuest;

  /// The display name of the user (or "Guest" for demo)
  String get displayName;

  /// The unique user ID (null for guests)
  String? get userId;

  /// Stakeholder roles selected by the user during onboarding.
  /// These are capabilities, not identity restrictions.
  /// Multiple roles can be selected simultaneously.
  List<String> get selectedRoles;

  /// Whether the user has completed onboarding (role selection, etc.)
  bool get hasCompletedOnboarding;
}

/// Special singleton for unauthenticated guest sessions.
class GuestSession implements AppSession {
  const GuestSession();

  @override
  SessionStatus get status => SessionStatus.guest;
  @override
  bool get isAuthenticated => false;

  @override
  bool get isGuest => true;
  @override
  String get displayName => 'Guest';

  @override
  String? get userId => null;
  @override
  List<String> get selectedRoles => const [];
  @override
  bool get hasCompletedOnboarding => false;
}

/// Session state for unauthenticated users who have NOT chosen guest mode yet.
/// This is the default state before session initialization completes.
/// Distinguished from GuestSession so the UI knows whether to show
/// the Welcome screen (UnauthenticatedSession) vs the Guest Home (GuestSession).
class UnauthenticatedSession implements AppSession {
  const UnauthenticatedSession();

  @override
  SessionStatus get status => SessionStatus.unauthenticated;
  @override
  bool get isAuthenticated => false;
  @override
  bool get isGuest => false;
  @override
  String get displayName => '';
  @override
  String? get userId => null;
  @override
  List<String> get selectedRoles => const [];
  @override
  bool get hasCompletedOnboarding => false;
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
  const AuthenticatedSession({
    this.userId,
    required this.displayName,
    this.selectedRoles = const [],
    this.hasCompletedOnboarding = false,
  });
  @override
  SessionStatus get status => SessionStatus.authenticated;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isGuest => false;

  /// Create a copy with updated fields.
  AuthenticatedSession copyWith({
    String? userId,
    String? displayName,
    List<String>? selectedRoles,
    bool? hasCompletedOnboarding,
  }) {
    return AuthenticatedSession(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      selectedRoles: selectedRoles ?? this.selectedRoles,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

