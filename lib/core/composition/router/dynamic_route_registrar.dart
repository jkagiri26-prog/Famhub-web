/// ============================================================
/// DYNAMIC ROUTE REGISTRAR (COMPOSITION ENGINE)
/// ============================================================
///
/// Routes come from Module Registry, not hardcoded.
/// Disabled modules don't even register routes.
/// The route table updates when runtime module availability changes.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/composition/providers/composition_providers.dart';
import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/shell/presentation/layouts/common/shell_not_found.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_catalog_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';
import 'package:famhub_app/core/workspace/application/current_workspace_contexts_provider.dart';

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/router/route_names.dart';
import 'package:famhub_app/system/registry/module_registry.dart';
import 'package:famhub_app/core/shell/presentation/pages/new_unified_app_shell.dart';
import 'package:famhub_app/core/shell/presentation/regions/unified_dashboard_host.dart';
import 'package:famhub_app/core/composition/domain/models/composition_metrics.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

// ── Module Page Imports ──
import 'package:famhub_app/features/farm_management/presentation/pages/farm_management_page.dart'
    as farm;
import 'package:famhub_app/features/marketplace/presentation/pages/marketplace_page.dart';
import 'package:famhub_app/features/analytics/presentation/pages/analytics_page.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_page.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_catalogue_page.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_management_page.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_provider_detail_page.dart';
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
import 'package:famhub_app/features/guest/famhub_home_page.dart';
import 'package:famhub_app/features/business_hub/presentation/pages/trader_workspace_gate.dart';

// ── Enterprise Phase: System Pages ──
import 'package:famhub_app/features/search/presentation/pages/global_search_page.dart';
import 'package:famhub_app/features/notifications/presentation/pages/notification_center_page.dart';
import 'package:famhub_app/features/settings/presentation/pages/runtime_settings_page.dart';
import 'package:famhub_app/features/reports/presentation/pages/reports_center_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/farmer_advisor_page.dart';
import 'package:famhub_app/features/weather/presentation/pages/weather_page.dart';

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
  static List<(String, String)> routeSignature(
    List<RuntimeModule> enabledModules,
  ) {
    final signature = <(String, String)>[];
    final workspaceBuilders = _workspaceBuilders(enabledModules);
    for (final module in enabledModules) {
      if (!module.isEnabled ||
          module.maintenanceMode ||
          ModulePageRegistry.resolve(module.moduleId) == null) {
        continue;
      }
      if (_canonicalWorkspaceKey(module.moduleId) != null) continue;
      final path =
          ModuleRegistry.byId(module.moduleId)?.entryRoute ?? module.route;
      signature.add((module.moduleId, path));
      if (module.moduleId == 'finance') {
        signature
          ..add((AppRoutes.financingCatalogName, AppRoutes.financingCatalog))
          ..add(
            (AppRoutes.financingManagementName, AppRoutes.financingManagement),
          )
          ..add(
            (
              AppRoutes.financingProviderDetailName,
              AppRoutes.financingProviderDetail,
            ),
          );
      }
    }
    for (final key in _workspaceKeys) {
      if (workspaceBuilders.containsKey(key)) {
        signature.add(_workspaceRoute(key));
      }
    }
    if (!workspaceBuilders.containsKey('trader')) {
      signature.add(_workspaceRoute('trader'));
    }
    return signature;
  }

  static GoRouter buildRouter(
    List<RuntimeModule> enabledModules, {
    CompositionMetricsCollector? metrics,
  }) {
    final stopwatch = Stopwatch()..start();
    final routes = _buildRoutes(enabledModules);

    final router = GoRouter(
      initialLocation: AppRoutes.root,
      routes: routes,
      errorBuilder: (context, state) => const ShellNotFound(),
    );

    stopwatch.stop();
    metrics?.recordRouteRegistrationDuration(stopwatch.elapsedMilliseconds);

    return router;
  }

  static RoutingConfig buildRoutingConfig(
    List<RuntimeModule> enabledModules, {
    CompositionMetricsCollector? metrics,
  }) {
    final stopwatch = Stopwatch()..start();
    final config = RoutingConfig(routes: _buildRoutes(enabledModules));
    stopwatch.stop();
    metrics?.recordRouteRegistrationDuration(stopwatch.elapsedMilliseconds);
    return config;
  }

  static GoRouter buildRouterWithConfig(
    ValueListenable<RoutingConfig> routingConfig,
  ) {
    return GoRouter.routingConfig(
      routingConfig: routingConfig,
      initialLocation: AppRoutes.root,
      errorBuilder: (context, state) => const ShellNotFound(),
    );
  }

  static List<RouteBase> _buildRoutes(List<RuntimeModule> enabledModules) {
    final moduleRoutes = <GoRoute>[];
    final workspaceBuilders = _workspaceBuilders(enabledModules);

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;
      if (_canonicalWorkspaceKey(module.moduleId) != null) continue;
      final builder = ModulePageRegistry.resolve(module.moduleId);
      if (builder == null) {
        debugPrint(
          '[DynamicRouteRegistrar] No page builder for "${module.moduleId}"',
        );
        continue;
      }
      // Route path is resolved from the static ModuleRegistry entry route
      // (falling back to the backend-provided route) so router paths always
      // match the routes used by navigation items.
      final def = ModuleRegistry.byId(module.moduleId);
      final path = def?.entryRoute ?? module.route;
      moduleRoutes.add(
        GoRoute(
          path: path,
          name: module.moduleId,
          builder: (context, state) => builder(context),
        ),
      );

      // Finance Phase 1 catalogue sub-pages.
      // Registered inside this loop (rather than as static shell routes) so
      // they only exist while the `finance` module is enabled — a disabled
      // module must not expose a catalogue entry point.
      if (module.moduleId == 'finance') {
        moduleRoutes.addAll([
          GoRoute(
            path: AppRoutes.financingCatalog,
            name: AppRoutes.financingCatalogName,
            builder: (context, state) => const FinancingCataloguePage(),
          ),
          GoRoute(
            path: AppRoutes.financingManagement,
            name: AppRoutes.financingManagementName,
            builder: (context, state) => const FinancingManagementPage(),
          ),
          GoRoute(
            path: AppRoutes.financingProviderDetail,
            name: AppRoutes.financingProviderDetailName,
            builder: (context, state) => FinancingProviderDetailPage(
              slug: state.pathParameters['slug'] ?? '',
            ),
          ),
        ]);
      }
    }

    // Workspace route identities are canonical and appear once, independently
    // of the runtime module route loop. Farm/Admin require an eligible runtime
    // module; Trader retains its legacy fallback only when no eligible Trader
    // builder is present. The route gate rejects configured-but-ineligible
    // Trader modules rather than bypassing enablement or maintenance.
    for (final key in _workspaceKeys) {
      final builder = workspaceBuilders[key] ??
          (key == 'trader' ? ModulePageRegistry.resolve('trader') : null);
      if (builder == null) continue;
      final (name, path) = _workspaceRoute(key);
      moduleRoutes.add(
        GoRoute(
          path: path,
          name: name,
          builder: (context, state) => _WorkspaceLandingRoute(
            workspaceKey: key,
            builder: builder,
          ),
        ),
      );
    }

    return [
      ShellRoute(
        builder: (context, state, child) => UnifiedAppShellV2(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.root,
            name: AppRoutes.rootName,
            builder: (context, state) => const UnifiedDashboardHost(),
          ),
          GoRoute(
            path: AppRoutes.home,
            name: AppRoutes.homeName,
            builder: (context, state) => const FamhubHomePage(inShell: true),
          ),
          GoRoute(
            path: AppRoutes.search,
            name: AppRoutes.searchName,
            builder: (context, state) => const GlobalSearchPage(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            name: AppRoutes.notificationsName,
            builder: (context, state) => const NotificationCenterPage(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            name: AppRoutes.reportsName,
            builder: (context, state) => const ReportsCenterPage(),
          ),
          GoRoute(
            path: AppRoutes.runtimeSettings,
            name: AppRoutes.runtimeSettingsName,
            builder: (context, state) => const RuntimeSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.aiAssistant,
            name: AppRoutes.aiAssistantName,
            builder: (context, state) =>
                const FarmerAdvisorPage(initialRoute: AppRoutes.aiAssistant),
          ),
          GoRoute(
            path: AppRoutes.weather,
            name: AppRoutes.weatherName,
            builder: (context, state) => const WeatherPage(),
          ),
          GoRoute(
            path: AppRoutes.guest,
            name: AppRoutes.guestName,
            builder: (context, state) => const FamhubHomePage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: AppRoutes.settingsName,
            builder: (context, state) => const SettingsPage(),
          ),
          ...moduleRoutes,
        ],
      ),
    ];
  }

  static GoRouter rebuildRouter(List<RuntimeModule> enabledModules) {
    return buildRouter(enabledModules);
  }

  static const _workspaceKeys = [
    'farm_management',
    'admin_console',
    'trader',
  ];

  static Map<String, ModulePageBuilder> _workspaceBuilders(
    List<RuntimeModule> modules,
  ) {
    final builders = <String, ModulePageBuilder>{};
    for (final module in modules) {
      if (!module.isEnabled || module.maintenanceMode) continue;
      final key = _canonicalWorkspaceKey(module.moduleId);
      if (key == null) continue;
      final builder = _workspacePageBuilder(module.moduleId);
      if (builder == null) continue;
      if (!builders.containsKey(key) || module.moduleId == key) {
        builders[key] = builder;
      }
    }
    return builders;
  }

  static String? _canonicalWorkspaceKey(String moduleId) {
    if (_workspaceKeys.contains(moduleId)) return moduleId;
    return moduleId == 'commerce' ? 'trader' : null;
  }

  static ModulePageBuilder? _workspacePageBuilder(String moduleId) =>
      ModulePageRegistry.resolve(moduleId) ??
      (moduleId == 'commerce' ? ModulePageRegistry.resolve('trader') : null);

  static (String, String) _workspaceRoute(String key) {
    switch (key) {
      case 'farm_management':
        return (AppRoutes.farmName, AppRoutes.farm);
      case 'admin_console':
        return (AppRoutes.adminName, AppRoutes.admin);
      case 'trader':
        return (AppRoutes.traderName, AppRoutes.trader);
      default:
        throw ArgumentError.value(key, 'key', 'Unknown workspace route');
    }
  }
}

class _WorkspaceLandingRoute extends ConsumerStatefulWidget {
  const _WorkspaceLandingRoute({
    required this.workspaceKey,
    required this.builder,
  });

  final String workspaceKey;
  final ModulePageBuilder builder;

  @override
  ConsumerState<_WorkspaceLandingRoute> createState() =>
      _WorkspaceLandingRouteState();
}

class _WorkspaceLandingRouteState
    extends ConsumerState<_WorkspaceLandingRoute> {
  bool _refreshing = true;
  bool _refreshFailed = false;
  int _refreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    _refreshActiveContext();
  }

  Future<void> _refreshActiveContext() async {
    final generation = ++_refreshGeneration;
    setState(() {
      _refreshing = true;
      _refreshFailed = false;
    });
    ref.invalidate(currentWorkspaceContextsProvider);
    try {
      await ref.read(contextProvider.notifier).init();
      if (!mounted || generation != _refreshGeneration) return;
      setState(() => _refreshing = false);
    } catch (error) {
      if (!mounted || generation != _refreshGeneration) return;
      debugPrint('[WorkspaceRoute] active context refresh failed: $error');
      setState(() {
        _refreshing = false;
        _refreshFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_refreshing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_refreshFailed) {
      return ErrorStateWidget(
        title: 'Workspace context unavailable',
        message: 'The active workspace context could not be refreshed.',
        retryLabel: 'Retry',
        onRetry: _refreshActiveContext,
      );
    }

    final session = ref.watch(sessionProvider);
    if (session is! AuthenticatedSession || !session.hasProfile) {
      return const ErrorStateWidget(
        title: 'Workspace unavailable',
        message: 'An authenticated profile is required to open this workspace.',
      );
    }

    final entityContext = ref.watch(contextProvider);
    if (entityContext.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final entityId = entityContext.entityId;
    final roleId = entityContext.roleId;
    final sessionUserId = session.userId;
    final sessionProfileId = session.profile?['id']?.toString();
    if (entityContext.isGuest ||
        sessionUserId == null ||
        sessionUserId.isEmpty ||
        entityContext.userId != sessionUserId ||
        sessionProfileId == null ||
        sessionProfileId.isEmpty ||
        entityContext.profileId != sessionProfileId ||
        entityId == null ||
        entityId.isEmpty ||
        roleId == null ||
        roleId.isEmpty) {
      return ErrorStateWidget(
        title: 'Workspace context unavailable',
        message:
            'Select or restore an active entity before opening this workspace.',
        retryLabel: 'Retry',
        onRetry: () => ref.read(contextProvider.notifier).init(),
      );
    }

    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final workspaceId = activeWorkspace.workspaceId;
    if (workspaceId.isEmpty ||
        !session.workspaceIds.contains(workspaceId) ||
        entityContext.activeWorkspaceId == null ||
        entityContext.activeWorkspaceId != workspaceId) {
      return ErrorStateWidget(
        title: 'Workspace unavailable',
        message:
            'The active workspace does not match the authenticated context.',
        retryLabel: 'Retry',
        onRetry: _refreshActiveContext,
      );
    }

    final authorizedContexts = ref.watch(currentWorkspaceContextsProvider);
    if (authorizedContexts.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (authorizedContexts.hasError) {
      return ErrorStateWidget(
        title: 'Workspace context unavailable',
        message: 'Authorized workspace contexts could not be confirmed.',
        retryLabel: 'Retry',
        onRetry: () => ref.invalidate(currentWorkspaceContextsProvider),
      );
    }
    final matchingContexts = authorizedContexts.requireValue.where((record) {
      if (record['workspace_id']?.toString() != workspaceId ||
          record['entity_id']?.toString() != entityId ||
          record['role_id']?.toString() != roleId ||
          record['business_profile_id']?.toString() !=
              entityContext.businessProfileId ||
          record['active_mode']?.toString() != entityContext.role) {
        return false;
      }
      final recordProfileId = record['profile_id']?.toString();
      return recordProfileId == null ||
          recordProfileId.isEmpty ||
          recordProfileId == entityContext.profileId;
    }).toList();
    if (matchingContexts.length != 1) {
      return const ErrorStateWidget(
        title: 'Workspace context unavailable',
        message:
            'The active entity and role do not resolve to one authorized workspace context.',
      );
    }

    final catalog = ref.watch(workspaceCatalogProvider);
    if (catalog.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (catalog.hasError) {
      return ErrorStateWidget(
        title: 'Workspace unavailable',
        message: 'The available workspaces could not be loaded.',
        retryLabel: 'Retry',
        onRetry: () => ref.invalidate(workspaceCatalogProvider),
      );
    }

    final activeWorkspaceEntries = catalog.requireValue
        .where((workspace) => workspace.id == activeWorkspace.workspaceId)
        .toList();
    if (activeWorkspaceEntries.length != 1) {
      return const ErrorStateWidget(
        title: 'Workspace unavailable',
        message: 'The active workspace could not be resolved.',
      );
    }
    final rawType = (activeWorkspaceEntries.single.category ??
            activeWorkspaceEntries.single.name)
        .trim();
    final activeType = WorkspaceDashboardCatalog.normalizeType(rawType);
    final expectedType = switch (widget.workspaceKey) {
      'farm_management' => 'farmer',
      'admin_console' => 'admin',
      'trader' => 'trader',
      _ => null,
    };
    if (activeType == null || activeType != expectedType) {
      return const ErrorStateWidget(
        title: 'Workspace context mismatch',
        message:
            'The requested workspace does not match the currently selected workspace.',
      );
    }

    final modules = ref.watch(moduleProvider);
    if (modules.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (modules.hasError) {
      return ErrorStateWidget(
        title: 'Workspace unavailable',
        message: 'Module availability could not be confirmed.',
        retryLabel: 'Retry',
        onRetry: () => ref.invalidate(moduleProvider),
      );
    }

    final runtimeModules = ref.watch(runtimeModuleRegistryProvider);
    final moduleKeyPriority = widget.workspaceKey == 'trader'
        ? const ['trader', 'commerce']
        : [widget.workspaceKey];
    String? selectedModuleKey;
    for (final key in moduleKeyPriority) {
      final configured = modules.requireValue
          .where((module) => module.moduleKey == key)
          .toList();
      if (configured.isEmpty) continue;
      if (configured.length != 1) {
        return const ErrorStateWidget(
          title: 'Workspace unavailable',
          message: 'The workspace module configuration is ambiguous.',
        );
      }
      if (!configured.single.isEnabled || configured.single.maintenanceMode) {
        continue;
      }
      final available = runtimeModules
          .where((module) => module.moduleId == key)
          .where((module) => module.isEnabled && !module.maintenanceMode)
          .toList();
      if (available.length > 1) {
        return const ErrorStateWidget(
          title: 'Workspace unavailable',
          message: 'The runtime workspace module is ambiguous.',
        );
      }
      if (available.length == 1) {
        selectedModuleKey = key;
        break;
      }
    }
    if (selectedModuleKey == null) {
      return const ErrorStateWidget(
        title: 'Workspace unavailable',
        message: 'This workspace module is not configured or available.',
      );
    }

    return widget.builder(context);
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
    'farm_management',
    (_) => const farm.FarmManagementPage(),
  );
  ModulePageRegistry.register('marketplace', (_) => const MarketplacePage());
  ModulePageRegistry.register('analytics', (_) => const AnalyticsPage());
  ModulePageRegistry.register('finance', (_) => const FinancingPage());
  ModulePageRegistry.register('logistics', (_) => const LogisticsPage());
  ModulePageRegistry.register('traceability', (_) => const TraceabilityPage());
  ModulePageRegistry.register('carbon_credit', (_) => const CarbonCreditPage());
  ModulePageRegistry.register('knowledge', (_) => const KnowledgeLinkPage());
  ModulePageRegistry.register('agribusiness', (_) => const AgribusinessPage());
  ModulePageRegistry.register(
    'opportunities',
    (_) => const OpportunitiesPage(),
  );
  ModulePageRegistry.register(
    'extension_services',
    (_) => const ExtensionServicesPage(),
  );
  ModulePageRegistry.register('agri_connect', (_) => const AgriConnectPage());
  ModulePageRegistry.register('agri_tech_lab', (_) => const AgriTechLabPage());
  ModulePageRegistry.register('referral_hub', (_) => const ReferralHubPage());
  ModulePageRegistry.register('profile', (_) => const ProfilePage());
  ModulePageRegistry.register('profile_settings', (_) => const SettingsPage());
  ModulePageRegistry.register(
    'admin_console',
    (_) => const AdminDashboardPage(),
  );
  ModulePageRegistry.register('trader', (_) => const TraderWorkspaceGate());

  // ── Enterprise System Pages ──
  ModulePageRegistry.register(
    'home',
    (_) => const FamhubHomePage(inShell: true),
  );
  ModulePageRegistry.register('search', (_) => const GlobalSearchPage());
  ModulePageRegistry.register(
    'notifications',
    (_) => const NotificationCenterPage(),
  );
  ModulePageRegistry.register('reports', (_) => const ReportsCenterPage());
  ModulePageRegistry.register('settings', (_) => const RuntimeSettingsPage());
  ModulePageRegistry.register(
    'ai_assistant',
    (_) => const FarmerAdvisorPage(initialRoute: AppRoutes.aiAssistant),
  );
}
