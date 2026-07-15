/// ============================================================
/// SESSION GATE — Session-aware app routing
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/session/ = session management layer
///
/// ✅ Responsibilities:
///   - Determine which screen to show based on session state
///   - Orchestrate splash → welcome → dashboard flow
///   - Provide loading screen during initialization
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

/// The main session gate that wraps the app.
/// Shows the appropriate screen based on session state.
///
/// Flow:
///   1. Loading → SplashScreenPage (until session initializes)
///   2. Unauthenticated → WelcomeScreenPage (sign in / create account / guest)
///   3. Guest → authenticatedBuilder (guest mode with demo data)
///   4. Authenticated → authenticatedBuilder (full mode)
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

    // Authenticated or Guest → Show main app
    return widget.authenticatedBuilder();
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
            if (success && mounted) navigator.pop();
            return success;
          },
          onSignUp: (email, password) async {
            final success = await ref.read(sessionProvider.notifier).signUp(
              email: email,
              password: password,
            );
            if (success && mounted) navigator.pop();
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
            if (success && mounted) navigator.pop();
            return success;
          },
          onSignUp: (email, password) async {
            final success = await ref.read(sessionProvider.notifier).signUp(
              email: email,
              password: password,
            );
            if (success && mounted) navigator.pop();
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

