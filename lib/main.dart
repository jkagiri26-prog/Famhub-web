import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router_provider.dart';

/// 🧠 Context Engine (SINGLE SOURCE OF TRUTH)
import 'core/context_engine/providers/context_provider.dart';

/// 🎨 Shell Theme (Domain-agnostic theming system)
import 'core/theme/app_theme.dart';

/// 🧠 Dashboard bootstrap system (OS layer)
import 'core/dashboard_engine/bootstrap/dashboard_bootstrap.dart';

/// 🔥 Runtime module synchronization engine
import 'core/module_runtime_sync/runtime_sync_engine.dart';
import 'core/module_runtime_sync/application/providers/module_runtime_sync_provider.dart';

/// 🔄 Workflow Orchestrator — bridges WorkflowEvents → Provider invalidation
import 'core/events/workflow_orchestrator.dart';
import 'core/events/event_bus_provider.dart';

/// 👁️ Event Observer — system-wide event telemetry
import 'core/observability/event_observer.dart';

/// 🏪 Provider invalidations for workflow orchestration
import 'features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'features/farm_management/application/providers/assets_provider.dart';
import 'features/marketplace/application/providers/marketplace_provider.dart';

/// 🚀 Startup Coordinator & Platform Persistence
import 'core/startup/startup_coordinator.dart';
import 'core/module_runtime_sync/infrastructure/persistence/persistence_store_factory.dart';

/// 📡 Centralized Supabase access
import 'core/services/supabase_service.dart';

/// 🧩 Module provider — fetches system.modules from backend
import 'core/providers/module_provider.dart';

// ╔══════════════════════════════════════════════════════════════╗
// ║  COMPOSITION ENGINE (RUNTIME COMPOSITION SYSTEM)            ║
// ╚══════════════════════════════════════════════════════════════╝
import 'core/composition/router/dynamic_route_registrar.dart'
    show bootstrapModulePageBuilders;
import 'core/composition/providers/composition_providers.dart';

import 'core/composition/bootstrap/module_descriptor_bootstrap.dart';

// ╔══════════════════════════════════════════════════════════════╗
// ║  PHASE C: RUNTIME CONTRIBUTION ENGINE & OBSERVABILITY       ║
// ╚══════════════════════════════════════════════════════════════╝
import 'core/composition/bootstrap/contribution_bootstrap.dart';
import 'core/composition/providers/contribution_providers.dart';
import 'core/composition/observability/contribution_observability.dart';
import 'core/dashboard_engine/application/observability/runtime_metrics_collector.dart';

import 'core/dashboard_engine/presentation/builders/phase_d_dashboard_bootstrap.dart';

// ╔══════════════════════════════════════════════════════════════╗
// ║  POLICY FRAMEWORK                                           ║
// ╚══════════════════════════════════════════════════════════════╝
import 'core/policies/bootstrap/policy_bootstrap.dart';

/// 🚪 Session Gate — startup orchestration with splash → welcome → app flow
import 'core/session/session_gate.dart';

/// ─────────────────────────────────────────────────────────────
/// ENTRY POINT
///
/// Startup flow:
///   runZonedGuarded()
///     ↓ WidgetsFlutterBinding.ensureInitialized()
///     ↓ configureGlobalErrorHandling()
///     ↓ Environment Validation
///     ↓ Supabase Initialization
///     ↓ Core Services & Composition Bootstrap
///     ↓ ProviderScope + runApp()
/// ─────────────────────────────────────────────────────────────
void main() async {
  // ── Phase 0: Platform initialization (must be outside zone) ──
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('1. Widgets initialized');

  // ── Phase 0b: Configure FlutterError + PlatformDispatcher ──
  // These must be set up before the zone so that errors that occur
  // within the zone's guard callback are still handled by the
  // same error handling infrastructure.
  configureGlobalErrorHandling();
  debugPrint('1a. Global error handling configured');

  // ── Phase 0c: Wrap all remaining startup in runZonedGuarded ──
  // This captures asynchronous uncaught exceptions that would
  // otherwise be lost (timers, stream callbacks, raw futures, etc.)
  runZonedGuarded(() async {
    await _bootstrap();
  }, (Object error, StackTrace stack) {
    // Fallback for any async error that:
    // - Wasn't caught by FlutterError.onError (non-Flutter errors)
    // - Wasn't caught by PlatformDispatcher.onError (async gaps)
    // - Happens in timers, raw isolates, or zone-unaware callbacks
    debugPrint('══════════════════════════════════════════════════');
    debugPrint('[ZONE] Uncaught async error in zone: $error');
    debugPrint('══════════════════════════════════════════════════');
    debugPrintStack(
      stackTrace: stack,
      label: '[ZONE] Stack trace',
      maxFrames: 20,
    );
  });
}

/// ─────────────────────────────────────────────────────────────
/// CORE BOOTSTRAP — Runs inside runZonedGuarded()
/// ─────────────────────────────────────────────────────────────
Future<void> _bootstrap() async {
  // ─────────────────────────────────────────────────────────────
  // PHASE 1: Validate configuration before any initialization
  // ─────────────────────────────────────────────────────────────
  if (!validateEnvironment()) {
    runConfigurationErrorApp(
      'Application configuration is incomplete.\n\n'
      'Please ensure SUPABASE_URL and SUPABASE_ANON_KEY are provided\n'
      'via --dart-define build arguments.',
    );
    return;
  }

  // ─────────────────────────────────────────────────────────────
  // PHASE 2: CRITICAL — Must complete before first frame
  // ─────────────────────────────────────────────────────────────

        // Stage 1: Supabase initialization (critical, with timeout & error handling)
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  debugPrint('===================================');
  debugPrint('[BOOT] COMPILE-TIME CONFIG');
  debugPrint('[BOOT] SUPABASE_URL = $supabaseUrl');
  debugPrint('[BOOT] URL endsWith(".co") = ${supabaseUrl.endsWith(".co")}');
  debugPrint('[BOOT] URL endsWith(".com") = ${supabaseUrl.endsWith(".com")}');
  debugPrint('[BOOT] ANON KEY LENGTH = ${anonKey.length}');
  debugPrint('===================================');

  final supabaseResult = await runStage(
    BootStage.supabaseInit,
    () => Supabase.initialize(
      url: supabaseUrl,
      anonKey: anonKey,
    ),
    timeout: const Duration(seconds: 15),
  );

  if (!supabaseResult.success) {
    runConfigurationErrorApp(
      'Failed to initialize the application backend.\n\n'
      'Error: ${supabaseResult.error}\n\n'
      'Please check your network connection and try again.',
    );
    return;
  }

  debugPrint('2. Supabase initialized');

  // ╔══════════════════════════════════════════════════════════════╗
  // ║  RUNTIME URL VERIFICATION                                   ║
  // ╚══════════════════════════════════════════════════════════════╝
    debugPrint('[BOOT] CLIENT URL = $supabaseUrl');

  // Stage 2: Create root ProviderContainer
  final container = ProviderContainer();
  debugPrint('3. ProviderContainer created');

  // Stage 3: Create persistence store (platform-agnostic)
  final persistenceStore = createPersistenceStore();

  // Stage 4: Create RuntimeSyncEngine (do NOT initialize yet)
  RuntimeSyncEngine? runtimeSyncEngine;
  try {
        runtimeSyncEngine = RuntimeSyncEngine(
      container: container,
      supabase: SupabaseService.instance.client,
      coordinator: container.read(moduleRuntimeSyncCoordinatorProvider),
      persistenceStore: persistenceStore,
    );
    debugPrint('[BOOT] RuntimeSyncEngine created successfully.');
  } catch (e, stack) {
    debugPrint('[BOOT] RuntimeSyncEngine creation failed: $e');
    debugPrintStack(
      stackTrace: stack,
      label: '[BOOT] RuntimeSyncEngine creation',
    );
    // Non-fatal — app can run without sync engine
  }

  // Stage 5: Workflow Orchestrator (generic event-to-provider binding)
  final orchestratorConfig = OrchestratorConfig(
    eventBridge: {
      'kpi_automation': [() => container.invalidate(farmDashboardProvider)],
      'stock_mutation': [
        () => container.invalidate(assetsProvider),
        () => container.invalidate(farmDashboardProvider),
      ],
      'production_publish': [
        () => container.invalidate(farmDashboardProvider),
        () => container.invalidate(marketplaceProvider),
      ],
      'production_to_marketplace': [
        () => container.invalidate(farmDashboardProvider),
        () => container.invalidate(marketplaceProvider),
      ],
    },
  );

  try {
    final orchestrator = WorkflowOrchestrator(
      bus: container.read(eventBusProvider),
      config: orchestratorConfig,
    );
    orchestrator.start();
    debugPrint('[BOOT] WorkflowOrchestrator started successfully.');
  } catch (e, stack) {
    debugPrint('[BOOT] WorkflowOrchestrator start failed: $e');
    debugPrintStack(stackTrace: stack, label: '[BOOT] WorkflowOrchestrator');
  }

  // ╔══════════════════════════════════════════════════════════════╗
  // ║  COMPOSITION ENGINE BOOTSTRAP                               ║
  // ╚══════════════════════════════════════════════════════════════╝
  // Stage 5b: Bootstrap module page builders for dynamic route generation
  try {
    bootstrapModulePageBuilders();
    debugPrint('[BOOT] Module page builders bootstrapped successfully.');
  } catch (e, stack) {
    debugPrint('[BOOT] Module page builders bootstrap failed: $e');
    debugPrintStack(stackTrace: stack, label: '[BOOT] Module page builders');
    // Non-fatal — app can fall back to static routes
  }

  // Stage 5c: Bootstrap module runtime descriptors for composition engine
  try {
    bootstrapModuleDescriptors();
    debugPrint('[BOOT] Module descriptors bootstrapped successfully.');
  } catch (e, stack) {
    debugPrint('[BOOT] Module descriptors bootstrap failed: $e');
    debugPrintStack(stackTrace: stack, label: '[BOOT] Module descriptors');
    // Non-fatal — composition engine can operate without descriptors
  }

  // ╔══════════════════════════════════════════════════════════════╗
  // ║  PHASE C: CONTRIBUTION REGISTRATION BOOTSTRAP              ║
  // ╚══════════════════════════════════════════════════════════════╝
  // Stage 5d: Bootstrap module contributions into ContributionRegistry
  // This bridges all module descriptors into the runtime contribution engine.
  try {
    bootstrapModuleContributions();
    debugPrint('[BOOT] Module contributions bootstrapped successfully.');
  } catch (e, stack) {
    debugPrint('[BOOT] Module contributions bootstrap failed: $e');
    debugPrintStack(stackTrace: stack, label: '[BOOT] Module contributions');
    // Non-fatal — composition engine can operate without contributions
  }

    // ╔══════════════════════════════════════════════════════════════╗
  // ║  PHASE D: LIVE DATA PROVIDERS & WIDGET REGISTRATIONS       ║
  // ╚══════════════════════════════════════════════════════════════╝
  // Stage 5e: Bootstrap Phase D workstreams
  // This connects module descriptors to live data providers,
  // registers dashboard widgets with the centralized registry,
  // and initializes observability integration.
  try {
    bootstrapPhaseD();
    debugPrint('[BOOT] Phase D bootstrapped successfully.');
  } catch (e, stack) {
    debugPrint('[BOOT] Phase D bootstrap failed: $e');
    debugPrintStack(stackTrace: stack, label: '[BOOT] Phase D');
    // Non-fatal — widgets fall back to empty state gracefully
  }

        // Stage 5f: Bootstrap policy framework
  // Registers all policy rule declarations. Must happen before
  // any policy queries are made. After capability bootstrap.
  try {
    await bootstrapPolicies();
    debugPrint('[BOOT] Policy framework bootstrapped successfully.');
  } catch (e, stack) {
    debugPrint('[BOOT] Policy framework bootstrap failed: $e');
    debugPrintStack(stackTrace: stack, label: '[BOOT] Policy framework');
    // Non-fatal — policies default to permissive
  }

    // Stage 5g: RuntimeMetricsCollector — initialized lazily via providers
  // Metrics collector is created on first access via the
  // runtimeMetricsCollectorProvider in observability_providers.dart.
  // No eager initialization needed here — it auto-starts on first use.

  // ╔══════════════════════════════════════════════════════════════╗
  // ║  EVENT OBSERVER — Start system-wide event telemetry        ║
  // ╚══════════════════════════════════════════════════════════════╝
  // Stage 5g: Start EventObserver for system-wide event telemetry.
  //           Non-critical — gracefully continues if it fails.
  try {
    final eventBus = container.read(eventBusProvider);
    final eventObserver = EventObserver(eventBus);
    eventObserver.start();
    debugPrint('[BOOT] EventObserver started successfully.');
  } catch (e, stack) {
    debugPrint('[BOOT] EventObserver start failed: $e');
    debugPrintStack(stackTrace: stack, label: '[BOOT] EventObserver');
    // Non-fatal — app can run without event observability
  }

  debugPrint('4. runApp()');

  // ─────────────────────────────────────────────────────────────
  // PHASE 3: runApp() — First frame MUST render now
  // ─────────────────────────────────────────────────────────────

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(runtimeSyncEngine: runtimeSyncEngine),
    ),
  );

  debugPrint('[BOOT] runApp() called — first frame rendering.');
}

class MyApp extends ConsumerStatefulWidget {
  final RuntimeSyncEngine? runtimeSyncEngine;

  const MyApp({super.key, this.runtimeSyncEngine});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _deferredInitStarted = false;

  @override
  void initState() {
    super.initState();

    // ─────────────────────────────────────────────────────────
    // PHASE 4: DEFERRED — After first frame via post-frame callback
    // ─────────────────────────────────────────────────────────
        WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_deferredInitStarted) return;
      _deferredInitStarted = true;

            // Stage 6: Context Engine initialization
      Future.microtask(() async {
        try {
          await ref.read(contextProvider.notifier).init();
          debugPrint('[BOOT] ContextEngine initialized successfully.');
          // REMOVED (2025): Manual invalidation of moduleProvider,
          // enabledRuntimeModulesProvider, runtimeModuleRegistryProvider,
          // and appRouterProvider is now redundant.
          // runtimeAutoInvalidatorProvider (consumed by
          // UnifiedAppShellV2) reactively invalidates navigation
          // providers when contextProvider changes, and composition
          // providers auto-rebuild via their reactive deps.
          debugPrint('[BOOT] Composition providers auto-refresh via runtimeAutoInvalidatorProvider.');
        } catch (e, stack) {
          debugPrint('[BOOT] ContextEngine init failed: $e');
          debugPrintStack(stackTrace: stack, label: '[BOOT] ContextEngine');
        }
      });

            // Stage 7: RuntimeSyncEngine deferred initialization
      final syncEngine = widget.runtimeSyncEngine;
      if (syncEngine != null) {
        Future.microtask(() async {
          try {
            await syncEngine.initialize().timeout(const Duration(seconds: 30));
            debugPrint('[BOOT] RuntimeSyncEngine initialized.');
            // REMOVED (2025): Manual invalidation of
            // moduleRuntimeSyncProvider, moduleProvider,
            // enabledRuntimeModulesProvider, runtimeModuleRegistryProvider,
            // and appRouterProvider is now redundant.
            // runtimeAutoInvalidatorProvider reactively watches
            // moduleProvider and contextProvider, and composition
            // providers auto-rebuild on their reactive deps.
            debugPrint('[BOOT] Runtime sync complete — providers auto-refresh.');
          } catch (e, stack) {
            debugPrint('[BOOT] RuntimeSyncEngine init failed: $e');
            debugPrintStack(
              stackTrace: stack,
              label: '[BOOT] RuntimeSyncEngine',
            );
            // Non-fatal — sync can retry later
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('5. MyApp.build()');

    // ╔══════════════════════════════════════════════════════════╗
    // ║  DIAGNOSTIC PHASES                                       ║
    // ║  Choose ONE phase below by commenting out the others.    ║
    // ╚══════════════════════════════════════════════════════════╝

    // ==========================================================
    // PHASE 2: Bypass Context Engine & Router
    // If this shows "FAMHUB Boot OK" → main() is working fine.
    // ==========================================================
    // return const MaterialApp(
    //   debugShowCheckedModeBanner: false,
    //   home: Scaffold(
    //     body: Center(child: Text('FAMHUB Boot OK')),
    //   ),
    // );

    // ==========================================================
    // PHASE 3: Verify Router
    // If Phase 2 works, swap to this.
    // Use `home:` instead of `routerConfig:` to bypass GoRouter.
    // ==========================================================
    // return MaterialApp(
    //   debugShowCheckedModeBanner: false,
    //   home: const Scaffold(
    //     body: Center(child: Text('Router Bypassed')),
    //   ),
    // );

    // ==========================================================
    // PHASE 4: Verify Dashboard Loading
    // If Phase 3 works, swap to this.
    // ==========================================================
    // return MaterialApp(
    //   debugShowCheckedModeBanner: false,
    //   home: const Scaffold(
    //     body: Text('Dashboard Loaded'),
    //   ),
    // );

                // ==========================================================
    // PRODUCTION: SessionGate orchestrates startup flow.
    // ---------------------------------------------------------
    // Flow:
    //   1. SessionGate shows SplashScreenPage during session init
    //   2. Unauthenticated → WelcomeScreenPage (Sign In / Guest)
    //   3. Guest or Authenticated → GoRouter-based app with ShellTheme
    // ==========================================================
    final shellTheme = ref.watch(shellThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: shellTheme.toThemeData(ThemeMode.light),
      darkTheme: shellTheme.toThemeData(ThemeMode.dark),
      themeMode: themeMode,
      home: SessionGate(
        authenticatedBuilder: () {
          final router = ref.watch(appRouterProvider);
          return MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            theme: shellTheme.toThemeData(ThemeMode.light),
            darkTheme: shellTheme.toThemeData(ThemeMode.dark),
            themeMode: themeMode,
          );
        },
      ),
    );
  }
}
