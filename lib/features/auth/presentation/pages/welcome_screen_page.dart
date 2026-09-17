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
import 'package:google_fonts/google_fonts.dart';

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
    final baseTheme = Theme.of(context);
    final theme = baseTheme.copyWith(
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme),
    );
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
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
                      isMobile ? 20 : 64,
                      24,
                      isMobile ? 18 : 48,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.06),
                          theme.scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        // ── Logo ──
                        Container(
                          width: isMobile ? 64 : 96,
                          height: isMobile ? 64 : 96,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primary,
                                colorScheme.primary.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.agriculture_rounded,
                            size: isMobile ? 32 : 48,
                            color: Colors.white,
                          ),
                        ),

                        SizedBox(height: isMobile ? 12 : 24),

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

                        SizedBox(height: isMobile ? 4 : 8),

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
                    padding: EdgeInsets.fromLTRB(
                      24,
                      isMobile ? 12 : 24,
                      24,
                      isMobile ? 16 : 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THE COMPLETE AGRICULTURAL ECOSYSTEM',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        if (isMobile)
                          ..._features.asMap().entries.map(
                            (entry) => _StaggeredFadeIn(
                              index: entry.key,
                              child: _WelcomeFeatureCard(
                                feature: entry.value,
                                colorScheme: colorScheme,
                                compact: true,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _features
                                .asMap()
                                .entries
                                .map(
                                  (entry) => SizedBox(
                                    width: isTablet
                                        ? (size.width - 72) / 2
                                        : (size.width - 72) / 3,
                                    child: _StaggeredFadeIn(
                                      index: entry.key,
                                      child: _WelcomeFeatureCard(
                                        feature: entry.value,
                                        colorScheme: colorScheme,
                                      ),
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
                    padding: EdgeInsets.fromLTRB(
                        24, 0, 24, isMobile ? 16 : 24),
                    child: Column(
                      children: [
                        // ── Sign In Button (Primary) ──
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: onSignIn,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 14 : 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              backgroundColor: colorScheme.primary,
                              elevation: 3,
                              shadowColor: colorScheme.primary
                                  .withValues(alpha: 0.35),
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

                        SizedBox(height: isMobile ? 10 : 12),

                        // ── Create Account Button (Secondary) ──
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: onCreateAccount,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 14 : 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              backgroundColor: colorScheme.surface,
                              side: BorderSide(
                                color: colorScheme.outline,
                                width: 1.5,
                              ),
                              elevation: 1,
                              shadowColor:
                                  Colors.black.withValues(alpha: 0.08),
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

                        SizedBox(height: isMobile ? 10 : 12),

                        // ── Continue Exploring Button ──
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: onContinueExploring,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 10 : 12),
                            ),
                            child: Text.rich(
                              TextSpan(
                                text: 'Continue ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Exploring',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
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
      ),
    );
  }
}

/// Feature card shown on welcome screen
class _WelcomeFeatureCard extends StatelessWidget {
  final _EcosystemFeature feature;
  final ColorScheme colorScheme;
  final bool compact;

  const _WelcomeFeatureCard({
    required this.feature,
    required this.colorScheme,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: compact ? 8.0 : 12.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10.0,
            offset: const Offset(0, 5),
            spreadRadius: -1.0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16.0),
          splashColor: Colors.black.withValues(alpha: 0.04),
          highlightColor: Colors.black.withValues(alpha: 0.04),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12.0 : 16.0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(compact ? 8.0 : 10.0),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(
                    feature.icon,
                    color: colorScheme.primary,
                    size: compact ? 22.0 : 24.0,
                  ),
                ),
                SizedBox(width: compact ? 12.0 : 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        feature.description,
                        maxLines: compact ? 2 : null,
                        overflow: compact
                            ? TextOverflow.ellipsis
                            : TextOverflow.clip,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: compact ? 11.5 : null,
                          height: compact ? 1.2 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20.0,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
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

/// Staggered fade/slide entrance used by the feature cards.
class _StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final int index;

  const _StaggeredFadeIn({
    required this.child,
    required this.index,
  });

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curve);
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}
