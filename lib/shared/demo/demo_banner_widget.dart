/// ============================================================
/// DEMO BANNER — Visual indicator for guest mode
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/demo/ = reusable demo data widgets
///
/// ✅ Responsibilities:
///   - Display a banner indicating the user is in demo/guest mode
///   - Offer sign-up/sign-in prompts
///   - Only appears in guest mode (controlled by session state)
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/session/session_gate.dart';
import 'package:famhub_app/features/auth/presentation/pages/sign_in_screen_page.dart';

/// A top banner that appears in guest mode.
/// Shows "Demo Mode" message with an option to sign in.
class DemoBanner extends ConsumerWidget {
  final VoidCallback? onSignIn;

  const DemoBanner({super.key, this.onSignIn});

  void _defaultSignIn(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const _DemoSignInSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    if (!isGuest) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade800,
            Colors.amber.shade600,
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demo Mode — Data shown is for illustration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onSignIn ?? () => _defaultSignIn(context, ref),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// FULL-SCREEN SIGN-IN SHEET — Pushed from demo banner
/// ============================================================
///
/// Opens a sign-in screen within the guest context.
/// On success, the app re-evaluates session state.
/// ============================================================
class _DemoSignInSheet extends ConsumerStatefulWidget {
  const _DemoSignInSheet();

  @override
  ConsumerState<_DemoSignInSheet> createState() => _DemoSignInSheetState();
}

class _DemoSignInSheetState extends ConsumerState<_DemoSignInSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Sign In',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SignInScreenPage(
        onSignIn: (email, password) async {
          final success = await ref.read(sessionProvider.notifier).signIn(
            email: email,
            password: password,
          );
          if (success && mounted) {
            Navigator.of(context).pop();
          }
          return success;
        },
        onSignUp: (email, password) async {
          final success = await ref.read(sessionProvider.notifier).signUp(
            email: email,
            password: password,
          );
          if (success && mounted) {
            // Navigate to onboarding then pop
            Navigator.of(context).pop();
          }
          return success;
        },
        onBack: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// A card/snackbar style notice for protected actions in demo mode.
/// Used instead of blocking the action entirely.
class DemoActionNotice extends StatelessWidget {
  final String actionName;
  final VoidCallback onContinue;
  final VoidCallback? onSignIn;

  const DemoActionNotice({
    super.key,
    required this.actionName,
    required this.onContinue,
    this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                'Demo Mode',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You are about to $actionName. '
            'In demo mode, this action will be simulated. '
            'Sign in to save real data.',
            style: TextStyle(
              color: Colors.brown.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onSignIn != null)
                TextButton(
                  onPressed: onSignIn,
                  child: const Text('Sign In'),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue in Demo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
