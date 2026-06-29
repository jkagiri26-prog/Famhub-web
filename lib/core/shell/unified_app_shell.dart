import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/providers/system_state_provider.dart';
import 'package:famhub_app/core/shell/app_shell_context.dart';
import 'package:famhub_app/core/shell/mobile_shell.dart';
import 'package:famhub_app/core/shell/tablet_shell.dart';
import 'package:famhub_app/core/shell/desktop_shell.dart';
import 'package:famhub_app/core/navigation/responsive_breakpoints.dart';
import 'package:famhub_app/core/navigation/runtime_refresh_provider.dart';
import 'package:famhub_app/core/dashboard_engine/application/observability/navigation_metrics.dart';

/// ============================================================
/// UNIFIED APP SHELL (ENTERPRISE GOVERNANCE)
/// ============================================================
///
/// ✅ Responsibilities:
///   - Responsive shell selection
///   - Runtime auto-invalidation for navigation
///   - Observability metrics
///   - System down gate
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - RuntimeRefreshProvider auto-invalidates when context/modules change
///   - NavigationMetrics tracks build performance
///   - No application restart required for backend changes
/// ============================================================
class UnifiedAppShell extends ConsumerWidget {
  final Widget child;

  const UnifiedAppShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemState = ref.watch(systemStateProvider);

    // ── Runtime auto-invalidation ──
    // Watches modules and context, invalidates navigation providers
    // when either changes. No app restart required.
    ref.watch(runtimeAutoInvalidatorProvider);

    // ── Start timing for observability ──
    final stopwatch = Stopwatch()..start();

    // ============================================================
    // SYSTEM DOWN GATE (GLOBAL BLOCKER)
    // ============================================================
    if (systemState.isSystemDown) {
      return const Scaffold(
        body: Center(
          child: Text('System maintenance in progress'),
        ),
      );
    }

    // ============================================================
    // RESPONSIVE SHELL WRAPPER
    // ============================================================
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrappedChild = AppShellContext(
          isGuest: false,
          isSystemDown: systemState.isSystemDown,
          child: child,
        );

        final width = constraints.maxWidth;

        Widget shell;
        if (ResponsiveBreakpoints.isMobile(width)) {
          shell = MobileShell(child: wrappedChild);
        } else if (ResponsiveBreakpoints.isTablet(width)) {
          shell = TabletShell(child: wrappedChild);
        } else {
          shell = DesktopShell(child: wrappedChild);
        }

        // Record build time for observability
        stopwatch.stop();
        navigationMetrics.recordDashboardRender(stopwatch.elapsedMilliseconds);

        return shell;
      },
    );
  }
}
