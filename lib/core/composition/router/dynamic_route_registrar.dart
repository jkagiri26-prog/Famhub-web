/// ============================================================
/// DYNAMIC ROUTE REGISTRAR (COMPOSITION ENGINE)
/// ============================================================
///
/// Routes come from Module Registry, not hardcoded.
/// Disabled modules don't even register routes.
/// Router auto-rebuilds when runtime registry changes.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/shell/presentation/layouts/common/shell_not_found.dart';

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/router/route_names.dart';
import 'package:famhub_app/core/shell/presentation/pages/new_unified_app_shell.dart';
import 'package:famhub_app/core/shell/presentation/regions/unified_dashboard_host.dart';
import 'package:famhub_app/core/composition/domain/models/composition_metrics.dart';

// ── Module Page Imports ──
import 'package:famhub_app/features/farm_management/presentation/pages/farm_dashboard_page.dart' as farm;
import 'package:famhub_app/features/marketplace/presentation/pages/marketplace_page.dart';
import 'package:famhub_app/features/analytics/presentation/pages/analytics_page.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_page.dart';
import 'package:famhub_app/features/logistics/presentation/pages/logistics_page.dart';
import 'package:famhub_app/features/traceability/presentation/pages/traceability_page.dart';
import 'package:famhub_app/features/carbon_credit/presentation/pages/carbon_credit_page.dart';
import 'package:famhub_app/features/knowledge_link/presentation/pages/knowledge_link_page.dart';
import 'package:famhub_app/features/agribusiness/presentation/pages/agribusiness_page.dart';
import 'package:famhub_app/features/opportunities/presentation/pages/opportunities_page.dart';
import 'package:famhub_app/features/extension_services/presentation/pages/extension_services_page.dart';
import 'package:famhub_app/features/agri_connect/presentation/pages/agri_connect_page.dart';
import 'package:famhub_app/features/agri_tech_lab/presentation/pages/agri_tech_lab_page.dart';
import 'package:famhub_app/features/refferal_hub/presentation/pages/referral_hub_page.dart';
import 'package:famhub_app/features/profile/presentation/pages/profile_page.dart';
import 'package:famhub_app/features/profile/presentation/pages/settings_page.dart';
import 'package:famhub_app/features/admin_console/presentation/pages/admin_dashboard_page.dart';
import 'package:famhub_app/features/guest/guest_homepage.dart';

// ── Enterprise Phase: System Pages ──
import 'package:famhub_app/features/home/presentation/pages/home_page.dart';
import 'package:famhub_app/features/search/presentation/pages/global_search_page.dart';
import 'package:famhub_app/features/notifications/presentation/pages/notification_center_page.dart';
import 'package:famhub_app/features/settings/presentation/pages/runtime_settings_page.dart';
import 'package:famhub_app/features/reports/presentation/pages/reports_center_page.dart';
import 'package:famhub_app/features/ai_assistant/presentation/pages/ai_assistant_page.dart';

/// Page builder type for module page registration
typedef ModulePageBuilder = Widget Function(BuildContext context);

/// ============================================================
/// MODULE PAGE REGISTRY
/// ============================================================
///
/// Maps module IDs to their page builders.
/// Registered during bootstrap, used during route building.
/// ============================================================
class ModulePageRegistry {
  static final Map<String, ModulePageBuilder> _builders = {};

  static void register(String moduleId, ModulePageBuilder builder) {
    if (_builders.containsKey(moduleId)) {
      debugPrint('[ModulePageRegistry] Overwriting builder for "$moduleId"');
    }
    _builders[moduleId] = builder;
  }

  static ModulePageBuilder? resolve(String moduleId) {
    return _builders[moduleId];
  }

  static bool hasBuilder(String moduleId) {
    return _builders.containsKey(moduleId);
  }

  static List<String> get registeredModules => _builders.keys.toList();

  static void clear() => _builders.clear();
}

/// ============================================================
/// DYNAMIC ROUTE REGISTRAR
/// ============================================================
///
/// Builds a GoRouter from the current set of enabled RuntimeModules.
/// Only enabled, non-maintenance modules get routes registered.
/// ============================================================
class DynamicRouteRegistrar {
  static GoRouter buildRouter(
    List<RuntimeModule> enabledModules, {
    CompositionMetricsCollector? metrics,
  }) {
    final stopwatch = Stopwatch()..start();
    final moduleRoutes = <GoRoute>[];

    for (final module in enabledModules) {
      if (module.maintenanceMode) continue;
      final builder = ModulePageRegistry.resolve(module.moduleId);
      if (builder == null) {
        debugPrint(
            '[DynamicRouteRegistrar] No page builder for "${module.moduleId}"');
        continue;
      }
      moduleRoutes.add(GoRoute(
        path: module.route,
        name: module.moduleId,
        builder: (context, state) => builder(context),
      ));
    }

    final router = GoRouter(
      initialLocation: AppRoutes.root,
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              UnifiedAppShellV2(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.root,
              name: AppRoutes.rootName,
              builder: (context, state) =>
                  const UnifiedDashboardHost(),
            ),
            GoRoute(
              path: AppRoutes.home,
              name: AppRoutes.homeName,
              builder: (context, state) =>
                  const HomePage(),
            ),
            GoRoute(
              path: AppRoutes.search,
              name: AppRoutes.searchName,
              builder: (context, state) =>
                  const GlobalSearchPage(),
            ),
            GoRoute(
              path: AppRoutes.notifications,
              name: AppRoutes.notificationsName,
              builder: (context, state) =>
                  const NotificationCenterPage(),
            ),
            GoRoute(
              path: AppRoutes.reports,
              name: AppRoutes.reportsName,
              builder: (context, state) =>
                  const ReportsCenterPage(),
            ),
            GoRoute(
              path: AppRoutes.runtimeSettings,
              name: AppRoutes.runtimeSettingsName,
              builder: (context, state) =>
                  const RuntimeSettingsPage(),
            ),
            GoRoute(
              path: AppRoutes.aiAssistant,
              name: AppRoutes.aiAssistantName,
              builder: (context, state) =>
                  const AIAssistantPage(),
            ),
            GoRoute(
              path: AppRoutes.guest,
              name: AppRoutes.guestName,
              builder: (context, state) =>
                  const GuestHomePage(),
            ),
            GoRoute(
              path: AppRoutes.settings,
              name: AppRoutes.settingsName,
              builder: (context, state) =>
                  const SettingsPage(),
            ),
            ...moduleRoutes,
          ],
        ),
      ],
      errorBuilder: (context, state) => const ShellNotFound(),
    );

    stopwatch.stop();
    metrics?.recordRouteRegistrationDuration(stopwatch.elapsedMilliseconds);

    return router;
  }

  static GoRouter rebuildRouter(List<RuntimeModule> enabledModules) {
    return buildRouter(enabledModules);
  }
}

/// ============================================================
/// BOOTSTRAP: REGISTER ALL MODULE PAGE BUILDERS
/// ============================================================
///
/// Called once during app initialization.
/// Registers page builders for every feature module.
/// The DynamicRouteRegistrar uses these to build routes.
/// ============================================================
void bootstrapModulePageBuilders() {
  // ── Feature Modules ──
  ModulePageRegistry.register(
      'farm_management', (_) => const farm.FarmManagementPage());
  ModulePageRegistry.register(
      'marketplace', (_) => const MarketplacePage());
  ModulePageRegistry.register(
      'analytics', (_) => const AnalyticsPage());
  ModulePageRegistry.register(
      'finance', (_) => const FinancingPage());
  ModulePageRegistry.register(
      'logistics', (_) => const LogisticsPage());
  ModulePageRegistry.register(
      'traceability', (_) => const TraceabilityPage());
  ModulePageRegistry.register(
      'carbon_credit', (_) => const CarbonCreditPage());
  ModulePageRegistry.register(
      'knowledge_link', (_) => const KnowledgeLinkPage());
  ModulePageRegistry.register(
      'agribusiness', (_) => const AgribusinessPage());
  ModulePageRegistry.register(
      'opportunities', (_) => const OpportunitiesPage());
  ModulePageRegistry.register(
      'extension_services', (_) => const ExtensionServicesPage());
  ModulePageRegistry.register(
      'agri_connect', (_) => const AgriConnectPage());
  ModulePageRegistry.register(
      'agri_tech_lab', (_) => const AgriTechLabPage());
  ModulePageRegistry.register(
      'referral_hub', (_) => const ReferralHubPage());
  ModulePageRegistry.register(
      'profile', (_) => const ProfilePage());
  ModulePageRegistry.register(
      'profile_settings', (_) => const SettingsPage());
  ModulePageRegistry.register(
      'admin_console', (_) => const AdminDashboardPage());

  // ── Enterprise System Pages ──
  ModulePageRegistry.register(
      'home', (_) => const HomePage());
  ModulePageRegistry.register(
      'search', (_) => const GlobalSearchPage());
  ModulePageRegistry.register(
      'notifications', (_) => const NotificationCenterPage());
  ModulePageRegistry.register(
      'reports', (_) => const ReportsCenterPage());
  ModulePageRegistry.register(
      'settings', (_) => const RuntimeSettingsPage());
  ModulePageRegistry.register(
      'ai_assistant', (_) => const AIAssistantPage());
}
