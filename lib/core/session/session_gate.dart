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
///   - Unauthenticated → FAMHUB Home (ecosystem showcase) / Welcome
///   - Authenticated + no profile → Create Profile
///   - Authenticated + profile + no workspaces → Workspace Selection
///   - Authenticated + profile + workspaces → Dashboard
///   - Active OTP session → OTP verification page (restored after restart)
///   - Restoration failure → retry/error state (never "brand-new user")
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Import feature modules directly
///   - Handle navigation events
/// ============================================================
library famhub_app.core.session.session_gate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/session_destination.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/theme/shell_theme.dart';
import 'package:famhub_app/features/auth/presentation/pages/splash_screen_page.dart';
import 'package:famhub_app/features/auth/presentation/pages/welcome_screen_page.dart';
import 'package:famhub_app/features/auth/presentation/pages/sign_in_screen_page.dart';
import 'package:famhub_app/features/auth/infrastructure/services/otp_session_storage.dart';
import 'package:famhub_app/core/services/auth_service.dart';
import 'package:famhub_app/core/theme/shell_theme_provider.dart';
import 'package:famhub_app/features/auth/presentation/pages/workspace_selection_page.dart';
import 'package:famhub_app/features/profile/presentation/pages/create_profile_page.dart';
import 'package:famhub_app/features/guest/famhub_home_page.dart';

/// The main session gate that wraps the app.
/// Shows the appropriate screen based on session state.
///
/// Startup Flow:
///   1. Initializing → SplashScreenPage (while restoring session → profile → workspaces)
///   2. Unauthenticated → WelcomeScreenPage
///      (Sign In / Create Account / Continue Exploring)
///   3. Active OTP Session → SignInScreenPage (OTP verification restored)
///   4. Authenticated (no profile) → Create Profile
///   5. Authenticated (profile, no workspaces) → Workspace Selection
///   6. Authenticated (profile, workspaces) → Dashboard
///   7. Restoration failure → retry/error state
///
/// Routing is driven entirely by the persisted session state published by
/// the SessionController — never by local booleans or cached navigation.
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
  bool _restoredOtpSession = false;
  bool _continueExploring = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = ref.read(sessionProvider.notifier);
    final status = await controller.initialize();
    debugPrint('[SESSION-DIAG] SessionGate._initialize -> status=$status '
        'state=${ref.read(sessionProvider).runtimeType} '
        'hasProfile=${ref.read(sessionProvider).hasProfile} '
        'workspaceIds=${ref.read(sessionProvider).workspaceIds}');

    // ── OTP SESSION RESTORATION ──
    // Check for a persisted OTP session. If one exists and is valid,
    // we should skip the welcome screen and show the OTP verification page.
    // This handles: app restart, browser refresh, low-memory process kill.
    final session = ref.read(sessionProvider);
    if (session is UnauthenticatedSession) {
      final stored = await OtpSessionStorage.loadSession();
      if (stored != null) {
        if (!stored.isExpired) {
          _restoredOtpSession = true;
        } else {
          // Clean up expired session
          await OtpSessionStorage.clearSession();
        }
      }
    }

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
    final destination = resolveSessionDestination(session);
    debugPrint('[SESSION-DIAG] SessionGate.build -> destination=$destination '
        'session=${session.runtimeType} '
        'hasProfile=${session.hasProfile} '
        'workspaceIds=${session.workspaceIds}');

    switch (destination) {
      // ── Still restoring startup state (session → profile → workspaces) ──
      // Never route while restoration is in progress — avoids the race where
      // the provider briefly looks like "no profile" and the gate opens
      // Create Profile before the backend query finishes.
      case SessionDestination.splash:
        return const SplashScreenPage();

      // ── Restoration failed (network / database error) ──
      // NOT the same as "no profile" or "no session". Show a retry state.
      case SessionDestination.error:
        if (session is SessionFailure) {
          return _buildErrorState(session.message);
        }
        return const SplashScreenPage();

      // ── OTP SESSION RESTORED ──
      // If there's a valid persisted OTP session and we're unauthenticated,
      // show the OTP verification page directly instead of the welcome screen.
      case SessionDestination.welcome:
        if (_restoredOtpSession && session is UnauthenticatedSession) {
          return _buildRestoredOtpFlow();
        }
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

      // Authenticated, no profile → Create Profile.
      case SessionDestination.createProfile:
        return _buildCreateProfile(session);

      // Authenticated, profile, no workspaces → Workspace Selection.
      case SessionDestination.workspaceSelection:
        return _buildWorkspaceSelection(session);

      // Authenticated, profile, workspaces → Dashboard.
      case SessionDestination.dashboard:
        return widget.authenticatedBuilder();
    }
  }

  /// Premium retry/error state — used when startup restoration fails.
  /// This is deliberately NOT a "brand-new user" experience.
  Widget _buildErrorState(String message) {
    final shellTheme = ref.watch(shellThemeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: shellTheme.toThemeData(ThemeMode.light),
      darkTheme: shellTheme.toThemeData(ThemeMode.dark),
      themeMode: themeMode,
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.06),
                cs.primary.withValues(alpha: 0.02),
                cs.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    elevation: 8,
                    shadowColor: cs.primary.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    color: cs.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: cs.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.cloud_off_outlined,
                              size: 30,
                              color: cs.error,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Something went wrong',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: () async {
                                setState(() => _initialized = false);
                                await _initialize();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the restored OTP flow when a valid OTP session exists
  /// from a previous run of the app (app restart, browser refresh, etc).
  Widget _buildRestoredOtpFlow() {
    final shellTheme = ref.watch(shellThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: shellTheme.toThemeData(ThemeMode.light),
      darkTheme: shellTheme.toThemeData(ThemeMode.dark),
      themeMode: themeMode,
      home: SignInScreenPage(
        onAuthenticate: ({
          required String contact,
          required String otp,
        }) async {
          final success = await _authenticateWithOtp(
            contact: contact,
            otp: otp,
          );
          if (success && mounted) {
            setState(() {
              _restoredOtpSession = false;
            });
          }
          return success;
        },
        onBack: () {
          // User pressed back — clear the restored session flag
          setState(() {
            _restoredOtpSession = false;
          });
          // Clear any persisted OTP session data
          OtpSessionStorage.clearSession();
        },
      ),
    );
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
        onComplete: () {
          // The CreateProfilePage already updated the session provider
          // (hasProfile = true). The gate rebuilds from persisted state
          // and routes to Workspace Selection because no workspaces exist.
          if (mounted) {
            setState(() {});
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
        onContinue: (workspaces) async {
          // Persist via the select-workspaces Edge Function. On success
          // the session provider publishes the backend response and the
          // gate routes to the dashboard.
          return ref
              .read(sessionProvider.notifier)
              .selectWorkspaces(workspaces);
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

      // Refresh session after successful OTP verification.
      // The refreshed session carries profile + workspace state, so the
      // gate routes to Create Profile / Workspace Selection / Dashboard
      // based on persisted state — no manual flag juggling.
      await ref.read(sessionProvider.notifier).refresh();

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

              // Refresh session after successful OTP verification.
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
