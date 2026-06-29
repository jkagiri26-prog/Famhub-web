// ignore: dangling_library_doc_comments
/// ============================================================
/// DESKTOP SHELL (RESPONSIVE SHELL VARIANT) — PHASE B
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Architecture Compliance:
///   - Desktop-specific shell layout (> 1024px)
///   - Animated left navigation sidebar (backend-driven)
///   - Enterprise desktop app bar
///   - Main dashboard content area
///   - Keyboard shortcuts (Ctrl+B, Ctrl+K, Ctrl+/, Esc)
///   - Focus management
///   - Breakpoint-aware resize optimization
///   - Performance measurement
///
/// ✅ Phase B Improvements:
///   - SidebarController (Riverpod) for expanded/collapsed state
///   - Smooth ~200ms animation for sidebar expand/collapse
///   - AnimatedSideNav with labels fade in/out
///   - DesktopAppBar with notifications, search, AI, settings, profile, context
///   - KeyboardShortcutsHandler using Flutter's Shortcuts/Actions/Focus
///   - ShellFocusScope for tab traversal
///   - BreakpointNotifier for debounced resize
///   - DesktopPerformanceMetrics for measuring rebuilds
///   - CompositionValidator to ensure all layouts share same pipeline
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Reference registries directly for business rules
///   - Hardcode navigation items
///   - Duplicate business logic from mobile/tablet
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/navigation/animated_side_nav.dart';
import 'package:famhub_app/core/navigation/resize_optimizer.dart';
import 'package:famhub_app/core/shell/desktop_app_bar.dart';
import 'package:famhub_app/core/shell/keyboard_navigation.dart';
import 'package:famhub_app/core/shell/focus_manager.dart';
import 'package:famhub_app/core/shell/desktop_performance.dart';
import 'package:famhub_app/core/shell/sidebar_controller.dart';
import 'package:famhub_app/core/providers/module_provider.dart';

class DesktopShell extends ConsumerStatefulWidget {
  final Widget child;

  const DesktopShell({
    super.key,
    required this.child,
  });
  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  final Stopwatch _buildStopwatch = Stopwatch();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Start performance measurement
    _buildStopwatch.start();

    // Check for any modules in maintenance mode
    final moduleAsync = ref.watch(moduleProvider);
    final hasMaintenance = moduleAsync.whenOrNull(
      data: (modules) => modules.any((m) => m.maintenanceMode),
    ) ?? false;

    // Initialize breakpoint state
    final breakpointNotifier = ref.read(breakpointProvider.notifier);

    // Wrap with keyboard shortcuts and focus management
    final content = KeyboardShortcutsHandler(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Initialize breakpoint on first build
              breakpointNotifier.setInitialWidth(constraints.maxWidth);

              // Record performance metrics
              _buildStopwatch.stop();
              desktopPerformance.recordSidebarBuild(
                _buildStopwatch.elapsedMilliseconds,
              );
              _buildStopwatch.reset();

              return Column(
                children: [
                  // ── Maintenance banner (if any modules are in maintenance) ──
                  if (hasMaintenance)
                    _MaintenanceBanner(),

                  // ── Top Application Bar ──
                  const DesktopAppBar(),

                  // ── Main Content Row (Sidebar + Content) ──
                  Expanded(
                    child: Row(
                      children: [
                        // ── Animated Navigation Sidebar ──
                        const AnimatedSideNav(),

                        // ── Vertical divider ──
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Colors.grey.shade200,
                        ),

                        // ── Main Content Area ──
                        Expanded(
                          child: Container(
                            color: const Color(0xFFF8F9FA),
                            child: widget.child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Wrap with focus scopes for tab traversal
    return ShellFocusScope(child: content);
  }
}

/// ============================================================
/// MAINTENANCE BANNER
/// ============================================================
///
/// Shows at the top when modules are in maintenance mode.
/// Driven entirely by backend module.maintenceMode field.
/// ============================================================
class _MaintenanceBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.engineering_outlined, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Some modules are under maintenance and may be temporarily unavailable.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

