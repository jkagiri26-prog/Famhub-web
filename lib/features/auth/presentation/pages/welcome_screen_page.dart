/// ============================================================
/// WELCOME SCREEN — Landing page for unauthenticated users
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/presentation/pages/ = page layer
///
/// ✅ Responsibilities:
///   - Present app brand and value proposition
///   - Display: Welcome to FAMHUB, Your Complete Agricultural Platform
/// - Offer "Sign In", "Create Account", and "Continue Exploring"
///   - Modern responsive design
///
/// ❌ Does NOT:
///   - Access Supabase directly
///   - Contain business logic
///   - Know about routing internals
/// ============================================================
library;

import 'package:flutter/material.dart';

/// Available ecosystem features shown on welcome screen
const List<_EcosystemFeature> _features = [
  _EcosystemFeature(
    icon: Icons.agriculture_outlined,
    title: 'Manage',
    description: 'Track crops, livestock, and farm operations',
  ),
  _EcosystemFeature(
    icon: Icons.swap_horiz_outlined,
    title: 'Trade',
    description: 'Buy and sell farm products directly',
  ),
  _EcosystemFeature(
    icon: Icons.school_outlined,
    title: 'Learn',
    description: 'Access agricultural knowledge and training',
  ),
  _EcosystemFeature(
    icon: Icons.people_outline,
    title: 'Connect',
    description: 'Network with the agricultural community',
  ),
  _EcosystemFeature(
    icon: Icons.trending_up_outlined,
    title: 'Grow',
    description: 'Scale your agricultural enterprise',
  ),
];

class WelcomeScreenPage extends StatelessWidget {
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onContinueExploring;

  const WelcomeScreenPage({
    super.key,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onContinueExploring,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // ── Top Section with Gradient ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      isMobile ? 40 : 64,
                      24,
                      isMobile ? 32 : 48,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.06),
                          colorScheme.surface,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        // ── Logo ──
                        Container(
                          width: isMobile ? 80 : 96,
                          height: isMobile ? 80 : 96,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                          ),
                          child: Icon(
                            Icons.agriculture_rounded,
                            size: isMobile ? 40 : 48,
                            color: colorScheme.primary,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Title ──
                        Text(
                          'Welcome to FAMHUB',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Subtitle ──
                        Text(
                          'Your Complete Agricultural Platform',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Tagline ──
                        Text(
                          'Manage. Trade. Learn. Connect. Grow.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Ecosystem Features Grid ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      24, 24, 24, 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'The complete agricultural ecosystem',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isMobile)
                          ..._features.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _WelcomeFeatureCard(
                                feature: f,
                                colorScheme: colorScheme,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _features
                                .map(
                                  (f) => SizedBox(
                                    width: isTablet
                                        ? (size.width - 72) / 2
                                        : (size.width - 72) / 3,
                                    child: _WelcomeFeatureCard(
                                      feature: f,
                                      colorScheme: colorScheme,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),

                  // ── Spacer ──
                  const Spacer(),

                  // ── Action Buttons ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        // ── Sign In Button (Primary) ──
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: onSignIn,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              backgroundColor: colorScheme.primary,
                            ),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Create Account Button (Secondary) ──
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: onCreateAccount,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(
                                color: colorScheme.outline,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Continue Exploring Button ──
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: onContinueExploring,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text.rich(
                              TextSpan(
                                text: 'Continue ',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Exploring',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feature card shown on welcome screen
class _WelcomeFeatureCard extends StatelessWidget {
  final _EcosystemFeature feature;
  final ColorScheme colorScheme;

  const _WelcomeFeatureCard({
    required this.feature,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ecosystem feature data class
class _EcosystemFeature {
  final IconData icon;
  final String title;
  final String description;

  const _EcosystemFeature({
    required this.icon,
    required this.title,
    required this.description,
  });
}
