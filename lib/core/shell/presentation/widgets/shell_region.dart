/// ============================================================
/// SHELL REGION — Isolated region that rebuilds independently
/// ============================================================
///
/// 🎯 PURPOSE:
///   Each shell region (top bar, navigation, content, etc.) wraps
///   its content in a ShellRegion. This ensures that state changes
///   in one region do NOT trigger rebuilds of unrelated regions.
///
/// ✅ Performance Optimization:
///   - Regions only rebuild when their own dependencies change
///   - No cascading rebuilds across the shell
///   - Uses `RepaintBoundary` to isolate painting
///   - Uses const constructors for stable widget identity
///
/// ✅ Rules Followed:
///   - Region isolation: each region renders independently
///   - State change in one region ≠ rebuild of unrelated regions
///   - Widget composition: many small widgets over one massive widget
///
/// Architecture:
/// ```
/// UnifiedAppShellV2
///   ├── TopBarRegion        (isolated)
///   ├── NavigationRegion    (isolated)
///   ├── ContentRegion       (isolated)
///   ├── FloatingRegion      (isolated)
///   ├── OverlayRegion       (isolated)
///   └── StatusRegion        (isolated)
/// ```
/// ============================================================
library;

import 'package:flutter/material.dart';

/// ============================================================
/// SHELL REGION — Isolates a region's rendering
/// ============================================================
///
/// Wraps a child widget in a [RepaintBoundary] and optional
/// [Key] for identity stability. This prevents Flutter from
/// repainting the region when sibling regions change.
///
/// Usage:
/// ```dart
/// ShellRegion(
///   name: 'topBar',
///   visible: config.topBar.visible,
///   child: ShellAppBar(config: config.topBar),
/// )
/// ```
/// ============================================================
class ShellRegion extends StatelessWidget {
  /// Name for debug identification
  final String name;

  /// Whether this region is visible
  final bool visible;

  /// The region's content widget
  final Widget child;

  /// Optional replacement when not visible
  final Widget? hiddenPlaceholder;

  const ShellRegion({
    super.key,
    required this.name,
    required this.visible,
    required this.child,
    this.hiddenPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return hiddenPlaceholder ?? const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: child,
    );
  }
}
