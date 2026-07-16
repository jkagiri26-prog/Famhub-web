/// ============================================================
/// SESSION GATE — Session-aware app routing
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/session/ = session management layer
///
/// ✅ Responsibilities:
///   - Determine which screen to show based on session state
///   - Orchestrate splash → welcome → role selection → dashboard flow
///   - Guest → FAMHUB Home (ecosystem showcase), NOT dashboard
///   - Authenticated → Role Selection (if needed) → Dashboard
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
import 'package:famhub_app/core/theme/shell_theme_provider.dart';
import 'package:famhub_app/features/auth/presentation/pages/role_selection_screen_page.dart';
import 'package:famhub_app/features/guest/guest_homepage.dart';

/// The main session gate that wraps the app.
/// Shows the appropriate screen based on session state.
///
/// Flow:
///   1. Loading → SplashScreenPage (until session initializes)
///   2. Unauthenticated → WelcomeScreenPage (sign in / create account / guest)
///   3. Guest → GuestHomePage (FAMHUB Home — ecosystem showcase)
///   4. Authenticated (no roles) → RoleSelectionScreenPage → Dashboard
///   5. Authenticated (with roles) → Dashboard
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
  bool _showRoleSelection = false;
  List<String> _pendingRoles = [];

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

    // Show role selection if triggered after auth
    if (_showRoleSelection) {
      return _buildRoleSelection(session);
    }

    // Unauthenticated (no session at all) → Show Welcome Screen
    if (session is UnauthenticatedSession) {
      return _AuthFlow(
        onSignIn: () => _showSignIn(),
        onCreateAccount: () => _showSignUp(),
        onContinueAsGuest: () {
          ref.read(sessionProvider.notifier).startGuestSession();
        },
      );
    }

    // Guest → Show FAMHUB Home (ecosystem showcase), NOT dashboard
    if (session is GuestSession) {
      return _GuestFlow();
    }

    // Authenticated → Check if onboarding (role selection) is complete
    if (session is AuthenticatedSession) {
      if (!session.hasCompletedOnboarding) {
        return _buildRoleSelection(session);
      }
      // Onboarding complete → show dashboard
      return widget.authenticatedBuilder();
    }

    // Fallback for any other state
    return const SplashScreenPage();
  }

  Widget _buildRoleSelection(AppSession session) {
    final shellTheme = ref.watch(shellThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: shellTheme.toThemeData(ThemeMode.light),
      darkTheme: shellTheme.toThemeData(ThemeMode.dark),
      themeMode: themeMode,
      home: RoleSelectionScreenPage(
        initialSelectedRoles: session.selectedRoles,
        onRolesChanged: (roles) {
          _pendingRoles = roles;
        },
        onContinue: () async {
          if (session is AuthenticatedSession) {
            await ref.read(sessionProvider.notifier).saveRoles(_pendingRoles);
          } else if (session is GuestSession) {
            ref.read(sessionProvider.notifier).completeGuestOnboarding(_pendingRoles);
          }
          if (mounted) {
            setState(() => _showRoleSelection = false);
          }
        },
      ),
    );
  }

  void _showSignIn() {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (context) => SignInScreenPage(
          onSignIn: (email, password) async {
            final success = await ref.read(sessionProvider.notifier).signIn(
              email: email,
              password: password,
            );
            if (success && mounted) {
              // Check if onboarding is needed
              final session = ref.read(sessionProvider);
              if (session is AuthenticatedSession && !session.hasCompletedOnboarding) {
                setState(() => _showRoleSelection = true);
              }
              navigator.pop();
            }
            return success;
          },
          onSignUp: (email, password) async {
            final success = await ref.read(sessionProvider.notifier).signUp(
              email: email,
              password: password,
            );
            if (success && mounted) {
              // New users always go through role selection
              setState(() => _showRoleSelection = true);
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
          onSignIn: (email, password) async {
            final success = await ref.read(sessionProvider.notifier).signIn(
              email: email,
              password: password,
            );
            if (success && mounted) {
              final session = ref.read(sessionProvider);
              if (session is AuthenticatedSession && !session.hasCompletedOnboarding) {
                setState(() => _showRoleSelection = true);
              }
              navigator.pop();
            }
            return success;
          },
          onSignUp: (email, password) async {
            final success = await ref.read(sessionProvider.notifier).signUp(
              email: email,
              password: password,
            );
            if (success && mounted) {
              setState(() => _showRoleSelection = true);
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
  final VoidCallback onContinueAsGuest;
  const _AuthFlow({
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onContinueAsGuest,
  });

  @override
  Widget build(BuildContext context) {
    return WelcomeScreenPage(
      onSignIn: onSignIn,
      onCreateAccount: onCreateAccount,
      onContinueAsGuest: onContinueAsGuest,
    );
  }
}

/// Guest flow widget showing FAMHUB Home with ecosystem showcase.
/// This is the entry point for all guest users.
/// Guests see the ecosystem showcase and can explore demo data.
class _GuestFlow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellTheme = ref.watch(shellThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: shellTheme.toThemeData(ThemeMode.light),
      darkTheme: shellTheme.toThemeData(ThemeMode.dark),
      themeMode: themeMode,
      home: const GuestHomePage(),
    );
  }
}

