/// ============================================================
/// EXPLORE BANNER — Visual indicator for unauthenticated browsing
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/demo/ = reusable demo data widgets
///
/// ✅ Responsibilities:
///   - Display a subtle banner indicating the user is browsing
///   - Offer sign-up/sign-in prompts
///   - Only appears for unauthenticated visitors
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';

/// A subtle banner that appears for unauthenticated visitors.
/// Shows a message about exploring with an option to sign in.
class ExploreBanner extends ConsumerWidget {
  final VoidCallback? onSignIn;

  const ExploreBanner({super.key, this.onSignIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    if (isAuthenticated) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.08),
            colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.explore_outlined, color: colorScheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Exploring FAMHUB — Sign in to save your data',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onSignIn ?? () {},
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
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

/// A card/snackbar style notice for protected actions.
/// Used instead of blocking the action entirely.
class ExploreActionNotice extends StatelessWidget {
  final String actionName;
  final VoidCallback onContinue;
  final VoidCallback? onSignIn;

  const ExploreActionNotice({
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
        color: colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Exploring',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You are about to $actionName. '
            'Sign in to save your data permanently.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
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
                  child: Text(
                    'Sign In',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: const Text('Continue Exploring'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
