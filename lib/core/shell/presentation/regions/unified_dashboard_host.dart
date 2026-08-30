import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/router/dynamic_route_registrar.dart';
import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/renderer/responsive_dashboard_renderer.dart';

/// ============================================================
/// UNIFIED DASHBOARD HOST — Workspace landing dispatcher
/// ============================================================
///
/// The root route ('/') is the selected workspace's landing/dashboard.
/// It dispatches DIRECTLY to the workspace's primary experience — the
/// existing module landing page — based on the active workspace type.
///
///   farmer            → FarmManagementPage      (farm_management)
///   trader / supplier → MarketplacePage         (marketplace)
///   institution       → FinancingPage           (finance)
///   service_provider  → ExtensionServicesPage   (extension_services)
///   knowledge_partner → KnowledgeLinkPage       (knowledge_link)
///
/// There is NO intermediate dashboard card the user must click to enter
/// the workspace, and NO redirect — the landing page renders in place.
///
/// Unmapped/unknown workspace types fall back to the curated workspace
/// dashboard (ResponsiveDashboardRenderer), never the generic
/// all-module directory.
///
/// ✅ Uses the existing ModulePageRegistry (single source of page
///    builders) and the existing workspace type mapping — the shell does
///    not import feature modules directly.
/// ============================================================
class UnifiedDashboardHost extends ConsumerWidget {
  const UnifiedDashboardHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the active workspace type. Null while the catalog loads;
    // the fallback renderer shows its own loading state meanwhile.
    final type = ref.watch(activeWorkspaceTypeProvider);
    final primaryKey = WorkspaceDashboardCatalog.primaryModuleKeyFor(type);
    final builder = primaryKey == null
        ? null
        : ModulePageRegistry.resolve(primaryKey);

    if (builder != null) {
      // Render the existing module landing page directly.
      return builder(context);
    }

    // Unknown/unmapped workspace → curated workspace-aware fallback.
    return const ResponsiveDashboardRenderer();
  }
}
