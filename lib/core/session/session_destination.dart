/// ============================================================
/// SESSION DESTINATION — Pure startup routing decision
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/session/ = session management layer
///
/// ✅ Responsibilities:
///   - Map an [AppSession] to the screen the SessionGate must show
///   - Pure function (no I/O) so the decision tree is unit-testable
///
/// Decision tree (driven purely by persisted state):
///   initializing                 → splash
///   SessionFailure (error)       → error (retry)   ← never "new user"
///   Unauthenticated              → welcome
///   Authenticated + no profile   → createProfile
///   Authenticated + profile + no workspaces → workspaceSelection
///   Authenticated + profile + workspaces    → dashboard
///
/// ❌ Does NOT:
///   - Perform I/O
///   - Know about widgets or navigation
/// ============================================================
library;

import 'package:famhub_app/core/session/app_session.dart';

/// The screen the SessionGate should present for a given session.
enum SessionDestination {
  /// Show the splash screen while startup state is restored.
  splash,

  /// Unauthenticated → Welcome / Sign In / Continue exploring.
  welcome,

  /// Restoration failed → retry/error state.
  error,

  /// Authenticated, no profile → Create Profile.
  createProfile,

  /// Authenticated, profile, no workspaces → Workspace Selection.
  workspaceSelection,

  /// Authenticated, profile, workspaces → Dashboard.
  dashboard,
}

/// Resolve the destination for a given session state.
SessionDestination resolveSessionDestination(AppSession session) {
  if (session.status == SessionStatus.initializing) {
    return SessionDestination.splash;
  }
  if (session is SessionFailure) {
    return SessionDestination.error;
  }
  if (session is UnauthenticatedSession) {
    return SessionDestination.welcome;
  }
  if (session is AuthenticatedSession) {
    if (!session.hasProfile) {
      return SessionDestination.createProfile;
    }
    if (session.workspaceIds.isEmpty) {
      return SessionDestination.workspaceSelection;
    }
    return SessionDestination.dashboard;
  }
  return SessionDestination.splash;
}
