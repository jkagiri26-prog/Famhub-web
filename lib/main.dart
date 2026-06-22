import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router_provider.dart';

/// 🧠 Context Engine (SINGLE SOURCE OF TRUTH)
import 'core/context_engine/providers/context_provider.dart';

/// 🧠 Dashboard bootstrap system (OS layer)
import 'core/dashboard_engine/bootstrap/dashboard_bootstrap.dart';

/// 🔥 Runtime module synchronization engine
import 'core/module_runtime_sync/runtime_sync_engine.dart';
import 'core/module_runtime_sync/application/providers/module_runtime_sync_provider.dart';

/// 🔄 Workflow Orchestrator — bridges WorkflowEvents → Provider invalidation
import 'core/events/workflow_orchestrator.dart';
import 'core/events/event_bus_provider.dart';

/// 🏪 Provider invalidations for workflow orchestration
import 'features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'features/farm_management/application/providers/assets_provider.dart';
import 'features/marketplace/application/providers/marketplace_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 🔌 SUPABASE BOOTSTRAP
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  /// 🌍 ROOT CONTAINER
  final container = ProviderContainer();

    /// 🚀 SYSTEM-DRIVEN DASHBOARD BOOTSTRAP
  // DashboardBootstrap.initialize() is called when widget builders are available.
  // Skipped here as it requires module-specific widget builders.
  // await DashboardBootstrap.initialize(builders: {});

    /// 🔥 LIVE MODULE RUNTIME SYNC ENGINE
  final runtimeSyncEngine = RuntimeSyncEngine(
    ref: container as Ref,
    supabase: Supabase.instance.client,
    coordinator: container.read(
      moduleRuntimeSyncCoordinatorProvider,
    ),
  );

  await runtimeSyncEngine.initialize();

  /// 🔄 WORKFLOW ORCHESTRATOR — BRIDGES EVENTS → PROVIDERS
  ///
  /// Creates a WorkflowOrchestrator with real provider invalidation
  /// callbacks. This ensures that when cross-module workflows
  /// (e.g., production → marketplace publish, kpi automation)
  /// emit WorkflowEvents, the relevant Riverpod providers are
  /// invalidated and the UI reactively updates.
  ///
  /// Callbacks use container.invalidate() rather than ref.invalidate()
  /// because we're outside the widget tree. The container is the
  /// root ProviderContainer used by the app.
  final orchestratorConfig = OrchestratorConfig(
    invalidateFarmDashboard: () {
      container.invalidate(farmDashboardProvider);
    },
    invalidateAssets: () {
      // assetsProvider is a family provider keyed by farmId.
      // We invalidate the provider itself, which forces re-creation
      // for all farm IDs on next access.
      container.invalidate(assetsProvider);
    },
    invalidateMarketplace: () {
      container.invalidate(marketplaceProvider);
    },
  );

  final orchestrator = WorkflowOrchestrator(
    bus: container.read(eventBusProvider),
    config: orchestratorConfig,
      );
  orchestrator.start();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
    );
  }

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
  }

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();

    /// 🧠 Context Engine Boot (SINGLE SOURCE OF TRUTH)
    Future.microtask(() async {
      await ref.read(contextProvider.notifier).init();
    });
}

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contextProvider);

    /// 🚨 GLOBAL SYSTEM LOADING GATE
    if (ctx.isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    /// 🧭 SYSTEM ROUTER
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,

      /// 🌐 THEME (FROM ENTITY CONTEXT)
      themeMode: _mapThemeMode(ctx.role ?? 'farmer'),

      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
    );
  }

  /// Temporary mapping until theme is fully moved to context_engine
  ThemeMode _mapThemeMode(String role) {
    // Replace later with real preference in EntityContext if needed
    return ThemeMode.system;
  }
}

