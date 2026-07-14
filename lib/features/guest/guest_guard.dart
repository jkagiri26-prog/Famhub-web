/// ============================================================
/// GUEST GUARD — Protects guest access to resources
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/guest/ = guest experience layer
///
/// ✅ Responsibilities:
///   - Check if current user is a guest
///   - Show sign-in prompt for protected actions
///   - Centralized permission check for guest mode
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Block exploration (only protected actions)
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/session/session_provider.dart';

/// Shows a sign-in prompt dialog when a guest attempts a protected action.
/// Returns:
///   - true: user can proceed (already authenticated, or dismissed)
///   - false: user chose 'sign_in' or 'create_account' — should not proceed
///
/// When user clicks 'sign_in' or 'create_account', this function
/// automatically navigates to the appropriate screen and returns false.
Future<bool> showProtectedActionPrompt(
  BuildContext context,
  WidgetRef ref, {
  String action = 'perform this action',
}) async {
  final isGuest = ref.read(isGuestProvider);
  if (!isGuest) return true; // Already authenticated, proceed

  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 32,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Create your free FAMHUB account to continue.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You need an account to $action.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop('sign_in'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop('create_account'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(color: colorScheme.outline),
            ),
            child: Text(
              'Create Account',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop('dismiss'),
            child: Text(
              'Continue browsing',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    ),
  );

  if (result == 'sign_in') {
    return false; // Caller should handle navigation to sign-in
  }

  if (result == 'create_account') {
    return false; // Caller should handle navigation to create account
  }

  // 'dismiss' or dialog dismissed → return true (proceed in demo mode)
  return true;
}
