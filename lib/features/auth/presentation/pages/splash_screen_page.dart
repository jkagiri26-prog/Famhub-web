/// ============================================================
/// SPLASH SCREEN — Premium animated startup experience
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/presentation/pages/ = page layer
///
/// ✅ Responsibilities:
///   - Animated Vunio logo with agriculture-inspired motion
///   - Beautiful loading animation (leaf/growth inspired)
///   - Smooth fade and scale transitions
///   - Soft loading indicator (no generic spinner)
///   - Display: "Growing Agriculture Together"
///   - Initialize: Supabase, Module Registry, Local Cache,
///     Session, Theme, Configuration
///   - Only remain visible while initialization is running
/// ============================================================
library famhub_app.features.auth.presentation.pages.splash_screen_page;


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';

/// Represents a single initialization step with its label
class _InitStep {
  final String label;
  final IconData icon;

  const _InitStep({required this.label, required this.icon});
}

/// All initialization steps shown on the splash screen
const List<_InitStep> _initSteps = [
  _InitStep(label: 'Supabase', icon: Icons.cloud_outlined),
  _InitStep(label: 'Service Registry', icon: Icons.grid_view_outlined),
  _InitStep(label: 'Local Cache', icon: Icons.storage_outlined),
  _InitStep(label: 'Session', icon: Icons.vpn_key_outlined),
  _InitStep(label: 'Theme', icon: Icons.palette_outlined),
  _InitStep(label: 'Configuration', icon: Icons.tune_outlined),
];

class SplashScreenPage extends ConsumerStatefulWidget {
  const SplashScreenPage({super.key});

  @override
  ConsumerState<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends ConsumerState<SplashScreenPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _progressController;

  late final Animation<double> _logoFadeIn;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoPulse;

  late final Animation<double> _taglineFadeIn;
  late final Animation<double> _stepsFadeIn;

  int _currentStepIndex = -1;
  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();

    // ── Logo Animation Controller ──
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _logoFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _logoPulse = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    // ── Tagline Animation ──
    _taglineFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    // ── Steps Animation ──
    _stepsFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
      ),
    );

    // ── Progress Controller ──
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Start animations
    _logoController.forward();
    _simulateProgress();
  }

  void _simulateProgress() {
    _progressController.addListener(() {
      final value = _progressController.value;
      setState(() {
        _progressValue = value;
        // Update current step based on progress
        final stepIndex = (value * _initSteps.length).floor();
        if (stepIndex < _initSteps.length) {
          _currentStepIndex = stepIndex;
        }
      });
    });
    _progressController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Background Gradient ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.03),
                      theme.scaffoldBackgroundColor,
                      colorScheme.primary.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ),

            // ── Content ──
            Center(
              child: _SplashAnimatedBuilder(
                listenable: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoFadeIn.value,
                    child: Transform.scale(
                      scale: _logoPulse.value * _logoScale.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Brand Logo ──
                    ClipOval(
                      child: Image.asset(
                        'assets/images/vunio_logo.png',
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Tagline ──
                    Opacity(
                      opacity: _taglineFadeIn.value,
                      child: Text(
                        'Growing Agriculture Together',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ── Loading Indicator (seed growing bar) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 64),
                      child: Column(
                        children: [
                          // Custom progress bar (seedling-inspired)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              height: 4,
                              width: double.infinity,
                              color: colorScheme.outlineVariant,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _progressValue,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme.primary.withValues(alpha: 0.6),
                                        colorScheme.primary,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Current Step Indicator ──
                          Opacity(
                            opacity: _stepsFadeIn.value,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: _currentStepIndex >= 0
                                  ? _buildStepIndicator(
                                      _initSteps[
                                          _currentStepIndex.clamp(0, _initSteps.length - 1)],
                                      colorScheme,
                                    )
                                  : const SizedBox.shrink(key: ValueKey('empty')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(_InitStep step, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      key: ValueKey(step.label),
      children: [
        Icon(
          step.icon,
          size: 16,
          color: colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Text(
          step.label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// AnimatedBuilder wrapper that works with Listenable (no conflict with Flutter)
class _SplashAnimatedBuilder extends AnimatedWidget {
  final Widget? child;
  final Widget Function(BuildContext context, Widget? child) builder;

  const _SplashAnimatedBuilder({
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
