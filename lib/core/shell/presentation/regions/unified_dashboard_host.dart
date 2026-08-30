import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/renderer/responsive_dashboard_renderer.dart';
import 'package:famhub_app/core/shell/presentation/layouts/common/common.dart';

/// ============================================================
/// UNIFIED DASHBOARD HOST (PRIMARY RUNTIME SHELL)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ CORRECT FLOW:
///   system.modules (backend) → ModuleService → moduleProvider
///   → navItem providers + active workspace → workspaceDashboardNavItemsProvider
///   → ResponsiveDashboardRenderer → Dashboard UI
///
/// ✅ Responsibilities:
///   - Responsive shell layout
///   - Render dashboard regions via ResponsiveDashboardRenderer
///   - Delegate loading/error/empty states to shared shell widgets
///   - Dashboard composition is workspace-aware (selected workspace
///     determines which modules are promoted on its Dashboard)
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - FULLY metadata-driven (backend registry is source of truth)
///   - FULLY registry-driven
///   - FULLY plugin-safe
///   - NO switch statements on module IDs
///   - NO hardcoded route maps
///   - NO hardcoded module names, descriptions, or icons
///   - NO conditional module metadata logic
///   - NO owned state implementations (delegated to shell)
///
/// ❌ Does NOT:
///   - Call Supabase directly
///   - Hardcode module lists
///   - Import registry into UI for business logic
///   - Perform access evaluation in widgets
///   - Place business logic in UI
///   - Bypass providers
///   - Know module IDs for icon/route/description resolution
///   - Own loading, error, or empty state implementations
/// ============================================================
class UnifiedDashboardHost extends ConsumerWidget {
  const UnifiedDashboardHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Loading/error gated on the backend module fetch. The renderer
    // handles the workspace-aware composition + empty state itself.
    final moduleAsync = ref.watch(moduleProvider);

    return moduleAsync.when(
      loading: () => const ShellDashboardLoading(),
      error: (error, stack) => ShellDashboardError(
        message: error.toString(),
        onRetry: () => ref.invalidate(moduleProvider),
      ),
      data: (_) => const ResponsiveDashboardRenderer(),
    );
  }
}

