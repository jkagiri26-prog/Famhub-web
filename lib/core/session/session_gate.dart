/// ============================================================
/// SESSION GATE — Session-aware app routing
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/session/ = session management layer
///
/// ✅ Responsibilities:
///   - Determine which screen to show based on session state
///   - Orchestrate splash → welcome → auth → profile → workspace → dashboard
///   - Unauthenticated → FAMHUB Home (ecosystem showcase)
///   - Authenticated + no profile → Create Profile
///   - Authenticated + profile + no workspaces → Workspace Selection
///   - Authenticated + profile + workspaces → Dashboard
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Import feature modules directly
///   - Handle navigation events
/// ============================================================
library famhub_app.core.session.session_gate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/theme/shell_theme.dart';
import 'package:famhub_app/features/auth/presentation/pages/splash_screen_page.dart';
import 'package:famhub_app/features/auth/presentation/pages/welcome_screen_page.dart';
import 'package:famhub_app/features/auth/presentation/pages/sign_in_screen_page.dart';
import 'package:famhub_app/core/services/auth_service.dart';
import 'package:famhub_app/core/theme/shell_theme_provider.dart';
import 'package:famhub_app/features/auth/presentation/pages/workspace_selection_page.dart';
import 'package:famhub_app/features/profile/presentation/pages/create_profile_page.dart';
import 'package:famhub_app/features/guest/famhub_home_page.dart';

/// The main session gate that wraps the app.
/// Shows the appropriate screen based on session state.
///
/// Startup Flow:
///   1. Initializing → SplashScreenPage
///   2. Unauthenticated → WelcomeScreenPage
///      (Sign In / Create Account / Continue Exploring)
///   3. Authenticated (no profile) → Create Profile → Workspace Selection → Dashboard
///   4. Authenticated (profile, no workspaces) → Workspace Selection → Dashboard
///   5. Authenticated (profile, workspaces) → Dashboard
///
/// There is no GuestSession. Guests are unauthenticated visitors.
/// FAMHUB Home is the public ecosystem entry point.
class SessionGate extends ConsumerStatefulWidget {
  final Widget Function() authenticatedBuilder;

  const SessionGate({
    super.key,
    required this.authenticatedBuilder,
  });

  @override
  ConsumerState<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends ConsumerState<SessionGate> {
  bool _initialized = false;
  bool _showCreateProfile = false;
  bool _showWorkspaceSelection = false;
  bool _continueExploring = false;
  List<String> _pendingWorkspaces = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = ref.read(sessionProvider.notifier);
    await controller.initialize();
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SplashScreenPage();
    }

    final session = ref.watch(sessionProvider);

    // Show create profile if triggered after auth
    if (_showCreateProfile) {
      return _buildCreateProfile(session);
    }

    // Show workspace selection if triggered after auth
    if (_showWorkspaceSelection) {
      return _buildWorkspaceSelection(session);
    }

    // Unauthenticated → Welcome Screen
    if (session is UnauthenticatedSession) {
      if (_continueExploring) {
        return _FamhubHomeFlow();
      }
      return _AuthFlow(
        onSignIn: () => _showSignIn(),
        onCreateAccount: () => _showSignUp(),
        onContinueExploring: () {
          setState(() => _continueExploring = true);
        },
      );
    }

    // Authenticated
    if (session is AuthenticatedSession) {
      // No profile yet → create profile
      if (!session.hasProfile) {
        return _buildCreateProfile(session);
      }

      // Profile exists but no workspaces selected → workspace selection
      if (!session.hasCompletedOnboarding) {
        return _buildWorkspaceSelection(session);
      }

      // Full onboarded user → dashboard
      return widget.authenticatedBuilder();
    }

    // Fallback
    return const SplashScreenPage();
  }

  Widget _buildCreateProfile(AppSession session) {
    final shellTheme = ref.watch(shellThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: shellTheme.toThemeData(ThemeMode.light),
      darkTheme: shellTheme.toThemeData(ThemeMode.dark),
      themeMode: themeMode,
      home: CreateProfilePage(
        onComplete: (displayName) async {
          await ref.read(sessionProvider.notifier).refresh();
          if (mounted) {
            setState(() => _showCreateProfile = false);
          }
        },
      ),
    );
  }

  Widget _buildWorkspaceSelection(AppSession session) {
    final shellTheme = ref.watch(shellThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: shellTheme.toThemeData(ThemeMode.light),
      darkTheme: shellTheme.toThemeData(ThemeMode.dark),
      themeMode: themeMode,
      home: WorkspaceSelectionPage(
        onWorkspacesChanged: (workspaces) {
          _pendingWorkspaces = workspaces;
        },
        onContinue: () async {
          if (_pendingWorkspaces.isNotEmpty) {
            await ref
                .read(sessionProvider.notifier)
                .saveWorkspaces(_pendingWorkspaces);
          }
          if (mounted) {
            setState(() => _showWorkspaceSelection = false);
          }
        },
      ),
    );
  }

  Future<bool> _authenticateWithOtp({
    required String contact,
    required String otp,
  }) async {
    try {
      final authService = AuthService();
      final result = await authService.verifyOtp(
        phone: contact,
        token: otp,
      );

      if (!result.success) {
        return false;
      }

      // Refresh session after successful OTP verification
      await ref.read(sessionProvider.notifier).refresh();

      if (!mounted) return true;

      // Check session state to decide next step
      final session = ref.read(sessionProvider);
      if (session is AuthenticatedSession) {
        if (!session.hasProfile) {
          setState(() => _showCreateProfile = true);
        } else if (!session.hasCompletedOnboarding) {
          setState(() => _showWorkspaceSelection = true);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  void _showSignIn() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (context) => SignInScreenPage(
          onAuthenticate: ({
            required String contact,
            required String otp,
          }) async {
            final success = await _authenticateWithOtp(
              contact: contact,
              otp: otp,
            );
            if (success && mounted) {
              navigator.pop();
            }
            return success;
          },
          onBack: () => navigator.pop(),
        ),
      ),
    );
  }

  void _showSignUp() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (context) => SignInScreenPage(
          onAuthenticate: ({
            required String contact,
            required String otp,
          }) async {
            final success = await _authenticateWithOtp(
              contact: contact,
              otp: otp,
            );
            if (success && mounted) {
              navigator.pop();
            }
            return success;
          },
          onBack: () => navigator.pop(),
        ),
      ),
    );
  }
}

/// Auth flow widget that shows the welcome screen.
class _AuthFlow extends StatelessWidget {
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onContinueExploring;
  const _AuthFlow({
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onContinueExploring,
  });

  @override
  Widget build(BuildContext context) {
    return WelcomeScreenPage(
      onSignIn: onSignIn,
      onCreateAccount: onCreateAccount,
      onContinueExploring: onContinueExploring,
    );
  }
}

/// FAMHUB Home flow — the public ecosystem showcase.
/// This is the entry point for unauthenticated (browsing) users.
/// Visitors see the real modules with sample/public data.
/// The exploration banner's "Sign In" button can trigger the auth flow.
class _FamhubHomeFlow extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FamhubHomeFlow> createState() => _FamhubHomeFlowState();
}

class _FamhubHomeFlowState extends ConsumerState<_FamhubHomeFlow> {
  void _navigateToSignIn() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (context) => SignInScreenPage(
          onAuthenticate: ({
            required String contact,
            required String otp,
          }) async {
            try {
              final authService = AuthService();
              final result = await authService.verifyOtp(
                phone: contact,
                token: otp,
              );

              if (!result.success) return false;

              // Refresh session after successful OTP verification
              await ref.read(sessionProvider.notifier).refresh();
              if (!mounted) return true;

              final session = ref.read(sessionProvider);
              if (session is AuthenticatedSession) {
                navigator.pop();
              }
              return true;
            } catch (_) {
              return false;
            }
          },
          onBack: () => navigator.pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shellTheme = ref.watch(shellThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: shellTheme.toThemeData(ThemeMode.light),
      darkTheme: shellTheme.toThemeData(ThemeMode.dark),
      themeMode: themeMode,
      home: Builder(
        builder: (context) => FamhubHomePage(
          onExploreSignIn: _navigateToSignIn,
        ),
      ),
    );
  }
}

