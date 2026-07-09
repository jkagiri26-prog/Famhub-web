# FAMHUB Startup Dependency Diagram

**Date**: June 2026  
**Diagram Type**: Execution order with dependency relationships
**Last Updated**: runZonedGuarded() wrapper added

---

## MAIN EXECUTION FLOW

```
main()
  │
  ├── (1) WidgetsFlutterBinding.ensureInitialized()
  │     └── Dependency: None (platform bootstrap)
  │     └── Type: SYNCHRONOUS — outside runZonedGuarded
  │     └── Bottleneck: ⚡ Minimal (<1ms)
  │
  ├── (2) configureGlobalErrorHandling()
  │     └── Sets FlutterError.onError + PlatformDispatcher.onError
  │     └── Dependency: WidgetsFlutterBinding (for PlatformDispatcher)
  │     └── Type: SYNCHRONOUS — outside runZonedGuarded
  │     └── Bottleneck: ⚡ None
  │
  ├── (3) runZonedGuarded(() async { _bootstrap(); })
  │     └── Captures all async uncaught exceptions (timers, streams, etc.)
  │     └── onError → logs to console with [ZONE] prefix
  │     └── Type: WRAPPER — all below runs inside this zone
  │
  │     ═══════ INSIDE runZonedGuarded ZONE ═══════
  │     │
  │     ├── (4) validateEnvironment()
  │     │     └── Dependency: None
  │     │     └── Type: SYNCHRONOUS
  │     │     └── On failure → runConfigurationErrorApp() → return
  │     │
  │     ├── (5) Supabase.initialize()
  │     │     └── Dependency: WidgetsFlutterBinding
  │     │     └── Type: ASYNCHRONOUS (AWAITED, with 15s timeout)
  │     │     └── Bottleneck: 🔴 Network I/O (100-500ms typical)
  │     │     └── On failure → runConfigurationErrorApp() → return
  │     │
  │     ├── (6) ProviderContainer()
  │     │     └── Dependency: Supabase.initialize (providers may read Supabase)
  │     │     └── Type: SYNCHRONOUS
  │     │     └── Bottleneck: ⚡ Minimal
  │     │
  │     ├── (7) createPersistenceStore()
  │     │     └── Dependency: None
  │     │     └── Type: SYNCHRONOUS
  │     │     └── Factory function (platform-agnostic wrapper)
  │     │
  │     ├── [BLOCK A: Pre-runApp Services]
  │     │     │
  │     │     ├── (8) RuntimeSyncEngine (constructor only)
  │     │     │     └── Dependency: container, SupabaseService, coordinator, persistenceStore
  │     │     │     └── Type: SYNCHRONOUS (try/catch wrapped)
  │     │     │     └── Bottleneck: ⚡ Minimal
  │     │     │
  │     │     ├── (9) WorkflowOrchestrator (constructor + start())
  │     │     │     └── Dependency: eventBusProvider (from container)
  │     │     │     └── Type: SYNCHRONOUS (try/catch wrapped)
  │     │     │     └── Bottleneck: ⚡ Minimal
  │     │     │
  │     │     ├── (10) bootstrapModulePageBuilders()
  │     │     │     └── Dependency: None (pure static registration)
  │     │     │     └── Type: SYNCHRONOUS (try/catch wrapped)
  │     │     │     └── Bottleneck: ⚡ Minimal (16 registrations)
  │     │     │
  │     │     ├── (11) bootstrapModuleDescriptors()
  │     │     │     └── Dependency: None (pure static registration)
  │     │     │     └── Type: SYNCHRONOUS (try/catch wrapped)
  │     │     │     └── Bottleneck: ⚡ Minimal
  │     │     │
  │     │     ├── (12) bootstrapModuleContributions()
  │     │     │     └── Dependency: Module descriptors (logical)
  │     │     │     └── Type: SYNCHRONOUS (try/catch wrapped)
  │     │     │     └── Bottleneck: ⚡ Minimal
  │     │     │
  │     │     ├── (13) bootstrapPhaseD()
  │     │     │     └── Dependency: Module descriptors (for widget registrations)
  │     │     │     └── Type: SYNCHRONOUS (try/catch wrapped)
  │     │     │     └── Bottleneck: ⚡ Minimal
  │     │     │
  │     │     └── (14) EventObserver (start system telemetry)
  │     │           └── Dependency: eventBusProvider (from container)
  │     │           └── Type: SYNCHRONOUS (try/catch wrapped)
  │     │           └── Bottleneck: ⚡ Minimal
  │     │
  │     ├── (15) runApp(UncontrolledProviderScope(MyApp))
  │     │     └── Dependency: ALL pre-runApp operations
  │     │     └── Type: BLOCKING
  │     │     └── Bottleneck: 🟡 Flutter framework first frame render
  │     │
  │     └── [POST-FRAME: Deferred Initializations]
  │           │
  │           ├── (16) ContextController.init()
  │           │     └── Dependency: contextProvider (watched in build())
  │           │     └── Type: ASYNCHRONOUS (post-frame microtask)
  │           │     └── Sub-operations:
  │           │           ├── storage.load() → shared_preferences (local I/O)
  │           │           └── sync.fetchUserContext() → Supabase RPC (network)
  │           │     └── Bottleneck: 🟡 Network I/O
  │           │     └── On completion → invalidates composition providers
  │           │
  │           └── (17) RuntimeSyncEngine.initialize()
  │                 └── Dependency: persistenceStore.initialize()
  │                 └── Type: ASYNCHRONOUS (post-frame microtask, 30s timeout)
  │                 └── Sub-operations:
  │                       ├── coordinator.bootstrap()
  │                       ├── persistenceStore.initialize()
  │                       ├── checkpoint restore
  │                       ├── widget hydration
  │                       ├── delta replay (journal events)
  │                       └── realtime subscription
  │                 └── Bottleneck: 🟡 Journal replay (depends on event backlog)
  │                 └── On completion → invalidates composition providers
```

---

## ERROR BARRIER ARCHITECTURE

```
                  ┌──────────────────────────────────────────┐
                  │           runZonedGuarded()               │
                  │   (dart:async — zone boundary)            │
                  │                                          │
                  │   Captures:                               │
                  │   • Unhandled async exceptions            │
                  │   • Timer/stream callback errors          │
                  │   • Raw future unhandled errors           │
                  │   • Isolate uncaught errors               │
                  └──────────────────┬───────────────────────┘
                                     │ supplements
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
 ┌────────▼─────────┐    ┌───────────▼────────────┐    ┌───────▼─────────────┐
 │ FlutterError     │    │ PlatformDispatcher     │    │ runZonedGuarded    │
 │ .onError         │    │ .onError               │    │ onError callback   │
 ├──────────────────┤    ├────────────────────────┤    ├────────────────────┤
 │ Flutter widget   │    │ Native platform        │    │ Async uncaught     │
 │ build/render     │    │ error callbacks         │    │ exceptions not     │
 │ errors           │    │ (iOS/macOS crash logs)  │    │ caught by above    │
 └──────────────────┘    └────────────────────────┘    └────────────────────┘
```

**All three layers work together:**

| Layer | Handler | Set up | What it catches |
|-------|---------|--------|-----------------|
| **Layer 1** | `FlutterError.onError` | `configureGlobalErrorHandling()` | Flutter widget build/render/assertion errors |
| **Layer 2** | `PlatformDispatcher.onError` | `configureGlobalErrorHandling()` | Native platform callbacks, app delegate errors |
| **Layer 3** | `runZonedGuarded` | `main()` wraps `_bootstrap()` | Any async error that slips through — timers, stream callbacks, unhandled futures |

---

## SERVICE DEPENDENCY GRAPH

```
                                ┌─────────────────────────┐
                                │    Supabase.instance     │
                                │   (initialized in main) │
                                └──────────┬──────────────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
         ┌──────────▼──────────┐ ┌─────────▼─────────┐ ┌─────────▼─────────┐
         │  SupabaseService    │ │  ModuleService     │ │  RuntimeSyncEngine│
         │  (singleton wrapper)│ │  (uses service)    │ │  (param injected) │
         └─────────────────────┘ └───────────────────┘ └───────────────────┘
                                           │                      │
                                           │                      │
                    ┌──────────────────────┼──────────────────────┘
                    │                      │
         ┌──────────▼──────────┐ ┌─────────▼──────────────────────────┐
         │  moduleProvider     │ │  moduleRuntimeSyncProvider          │
         │  (Riverpod Future)  │ │  (Riverpod Notifier)                │
         └─────────────────────┘ └────────────────────────────────────┘
                    │                      │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼──────────────────────────┐
                    │  runtimeModuleRegistryProvider       │
                    │  (combines modules + context)        │
                    └─────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
 ┌────────▼────────┐ ┌────────▼────────┐ ┌─────────▼──────────┐
 │ composition*    │ │ dashboard*      │ │ contribution*      │
 │ providers       │ │ providers       │ │ providers          │
 │ (nav items,     │ │ (widget lists,  │ │ (settings, reports,│
 │  routes, etc.)  │ │  floating btns) │ │  AI providers...)  │
 └─────────────────┘ └─────────────────┘ └────────────────────┘
```

---

## INITIALIZATION ORDER

```
Phase 0: PLATFORM (outside runZonedGuarded)
  [0a] WidgetsFlutterBinding.ensureInitialized()
  [0b] configureGlobalErrorHandling()

Phase 0c: runZonedGuarded() — error barrier starts
  │
  ├── Phase 1: BOOTSTRAP (blocking, awaited)
  │   [1] validateEnvironment()
  │   [2] Supabase.initialize() ─── AWAITED, 15s timeout
  │
  ├── Phase 2: PRE-RENDER (synchronous, sequential)
  │   [3] ProviderContainer
  │   [4] createPersistenceStore()
  │   [5] RuntimeSyncEngine (constructor)
  │   [6] WorkflowOrchestrator (constructor + start)
  │   [7] bootstrapModulePageBuilders()
  │   [8] bootstrapModuleDescriptors()
  │   [9] bootstrapModuleContributions()
  │   [10] bootstrapPhaseD()
  │   [11] EventObserver (start)
  │
  ├── Phase 3: FIRST FRAME (blocking)
  │   [12] runApp() → MyApp.build()
  │        ├── contextProvider.watch() → isLoading=true → loading spinner
  │        └── appRouterProvider.watch() → GoRouter instance
  │
  └── Phase 4: DEFERRED (post-frame, non-blocking)
      [13a] ContextController.init()
      [13b] → composition invalidation (re-render with context)
      [14a] RuntimeSyncEngine.initialize()
      [14b] → composition invalidation (re-render with runtime state)
```

---

## BLOCKING OPERATIONS

| # | Operation | Type | Typical Duration | Risk |
|---|-----------|------|------------------|------|
| 1 | `Supabase.initialize()` | Network | 100-500ms | 🔴 **Timeouts on slow networks** (15s cap) |
| 2 | `runApp()` | Framework | 50-200ms | 🟡 Widget tree construction |
| 3 | First Provider resolution | Lazy eval | 10-50ms | 🟡 Depends on provider complexity |

---

## ASYNCHRONOUS OPERATIONS

| # | Operation | Trigger | Duration | Risk |
|---|-----------|---------|----------|------|
| 1 | `ContextController.init()` | Post-frame | 50-300ms | 🟡 Network failure → fallback to local |
| 2 | `RuntimeSyncEngine.initialize()` | Post-frame | 100ms-5s | 🟡 Journal replay, checkpoint restore |
| 3 | `moduleProvider` resolution | First watch | 50-200ms | 🟡 Network fetch, cached thereafter (TTL) |

---

## STARTUP BOTTLENECKS

| Bottleneck | Location | Impact | Mitigation |
|------------|----------|--------|------------|
| **Supabase.initialize()** | main.dart | ~100-500ms blocking | ✅ 15s timeout |
| **Sequential registrations** | main.dart (#3-#11) | ~5-10ms total | ✅ Negligible |
| **First ProviderContainer render** | MyApp.build() | First frame shows loading spinner | ✅ Expected pattern |
| **Context init fetch** | Post-frame | ~50-300ms after first frame | ✅ Non-blocking |
| **RuntimeSync init** | Post-frame | ~100ms-5s after first frame | ✅ Non-blocking, 30s timeout |

---

## COMPLIANCE SUMMARY

| Requirement | Status | Notes |
|-------------|--------|-------|
| ✅ `runZonedGuarded` wrapper | **DONE** | Wraps entire `_bootstrap()` after binding + error handling setup |
| ✅ Global error handling (FlutterError + PlatformDispatcher) | **DONE** | `configureGlobalErrorHandling()` in `startup_coordinator.dart` |
| ✅ EventObserver started | **DONE** | Started in pre-runApp phase |
| ✅ ModuleService TTL cache | **DONE** | 5-minute TTL + stale fallback + `invalidateCache()` |
| ✅ SupabaseService standardization | **DONE** | `ModuleService` + `main.dart` use `SupabaseService.instance.client` |
| ✅ Startup synchronization | **DONE** | Composition invalidation after deferred inits |
| ✅ Router investigation | **DONE** | `FAMHUB_ROUTER_ARCHITECTURE_INVESTIGATION.md` |
| ❌ Router code changes | **HOLD** | Per approved plan — not implemented |
| ❌ DashboardBootstrap | **HOLD** | Will be addressed later |
| ❌ Feature module changes | **HOLD** | Not in scope |
