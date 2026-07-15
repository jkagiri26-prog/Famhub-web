# FAMHUB Stage 2 — Dashboard Runtime Architecture & Audit Report

**Audit Date**: June 2026  
**Scope**: Full runtime architecture audit — from module registration through governance pipeline to runtime execution  
**Methodology**: Deep code trace of every engine, registry, pipeline, and composition layer  
**Status**: ✅ **COMPLETED** — All layers verified against actual source code

---

## TABLE OF CONTENTS

A. Architecture Overview — The 6-Layer Runtime Model  
B. Layer 1: Static Registries (System/Registries)  
C. Layer 2: Module Runtime Descriptors  
D. Layer 3: Composition Engine  
E. Layer 4: Governance & Decision Engine  
F. Layer 5: Dashboard Runtime Engine  
G. Layer 6: Runtime Sync Engine  
H. Cross-Cutting: Event Bus & Workflow Orchestrator  
I. Data Flow End-to-End Walkthrough  
J. Architecture Compliance Matrix  
K. Issues Found  
L. Recommendations & Migration Path  

---

## A. ARCHITECTURE OVERVIEW — THE 6-LAYER RUNTIME MODEL

The FamHub runtime is organized into 6 distinct layers, each with a single responsibility, clear boundaries, and strict import rules. Below is the formal model.

```
┌──────────────────────────────────────────────────────────────────────┐
│  LAYER 1: STATIC REGISTRIES   (system/registry/)                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ ModuleRegistry  ·  DependencyRegistry  ·  RouteRegistry      │   │
│  │ FeatureRegistry ·  AccessRegistry                            │   │
│  │                                                              │   │
│  │ PURE: No runtime state, no services, no UI, no async, no     │   │
│  │ providers. Static const lists only.                          │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
                                │ feeds blueprints to
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  LAYER 2: MODULE CONTRIBUTIONS   (features/*/bootstrap/)             │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ ModuleRuntimeDescriptor  ·  Widget builders  ·  Shell exts   │   │
│  │                                                              │   │
│  │ Each module contributes a descriptor at bootstrap time.      │   │
│  │ Contains ONLY metadata — no widget trees, no rendering.      │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
                                │ descriptors consumed by
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  LAYER 3: COMPOSITION ENGINE   (core/composition/)                   │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ RuntimeCompositionEngine  ·  ContributionEngine              │   │
│  │ ModuleAccessFilter  ·  DependencyResolver                    │   │
│  │ ModuleToRuntimeMapper                                       │   │
│  │                                                              │   │
│  │ Builds RuntimeModuleRegistry from raw SystemModules.         │   │
│  │ Pipeline: fetch → filter → resolve deps → map → output.     │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
                                │ evaluated by
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  LAYER 4: GOVERNANCE & DECISIONS  (core/runtime_decision/)           │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ RuntimeDecisionEngine  ←  CapabilityEngine                  │   │
│  │                         ←  PolicyEngine                     │   │
│  │                         ←  AccessDecisionEngine             │   │
│  │                         ←  RuntimeFeatureFlags              │   │
│  │                                                              │   │
│  │ SINGLE evaluation engine. Every governance layer in order.   │   │
│  │ Returns structured RuntimeDecision with explanation.         │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
                                │ outputs to
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  LAYER 5: DASHBOARD RUNTIME ENGINE  (core/dashboard_engine/)         │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ DashboardCompositionEngine  ·  DashboardRenderer              │   │
│  │ RuntimePipelineOrchestrator  ·  ConflictBuffer                │   │
│  │ WidgetResolutionEngine  ·  LayoutResolver                     │   │
│  │ WidgetHydrationEngine                                       │   │
│  │                                                              │   │
│  │ Renders widgets in dashboard sections.                       │   │
│  │ Pipeline: reconcile → diff → patch → execute.                │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
                                │ synced by
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  LAYER 6: RUNTIME SYNC ENGINE  (core/module_runtime_sync/)           │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ RuntimeSyncEngine  ·  EventJournal  ·  CheckpointStore       │   │
│  │ ModuleRuntimeSyncCoordinator  ·  ConflictBuffer              │   │
│  │                                                              │   │
│  │ Event-driven runtime: realtime subscriptions + delta replay. │   │
│  │ Durable persistence, crash recovery, adaptive batching.      │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## B. LAYER 1: STATIC REGISTRIES (system/registry/)

### B.1 Location & Architecture

**Path**: `lib/system/registry/`  
**Purpose**: Pure declarative catalog of all system module blueprints, dependencies, features, and access rules.  
**Architecture Mandate**: Absolutely NO runtime state, NO services, NO UI, NO async operations, NO providers.

### B.2 Registry Inventory

| Registry | File | Contents | Pattern |
|----------|------|----------|---------|
| `ModuleRegistry` | `module_registry.dart` | 16 static `ModuleDefinition` constants | `static const List<ModuleDefinition>` |
| `DependencyRegistry` | `dependency_registry.dart` | 16 static `DependencyEdge` constants | `static const List<DependencyEdge>` |
| `FeatureRegistry` | `feature_registry.dart` | Feature flags per module | Static definitions |
| `AccessRegistry` | `access_registry.dart` | Role → permission mappings | Static rules |
| `RouteRegistry` | `route_registry.dart` | Module ID → route path | Static mappings |

### B.3 ModuleRegistry Definitions (16 Modules)

| # | Module ID | Route | Icon | Order | Default Enabled |
|---|-----------|-------|------|-------|-----------------|
| 1 | `farm_management` | `/farm` | agriculture | 1 | ✅ Yes |
| 2 | `marketplace` | `/marketplace` | store | 2 | ✅ Yes |
| 3 | `analytics` | `/analytics` | analytics | 3 | ✅ Yes |
| 4 | `financing` | `/financing` | finance | 4 | ✅ Yes |
| 5 | `logistics` | `/logistics` | shipping | 5 | ✅ Yes |
| 6 | `traceability` | `/traceability` | qr_code | 6 | ✅ Yes |
| 7 | `carbon_credit` | `/carbon-credit` | eco | 7 | ✅ Yes |
| 8 | `knowledge_link` | `/knowledge` | library | 8 | ✅ Yes |
| 9 | `agribusiness` | `/agribusiness` | business | 9 | ✅ Yes |
| 10 | `opportunities` | `/opportunities` | opportunities | 10 | ✅ Yes |
| 11 | `extension_services` | `/extension` | support | 11 | ✅ Yes |
| 12 | `agri_connect` | `/connect` | community | 12 | ✅ Yes |
| 13 | `agri_tech_lab` | `/tech-lab` | science | 13 | ✅ Yes |
| 14 | `referral_hub` | `/referrals` | referral | 14 | ✅ Yes |
| 15 | `profile` | `/profile` | profile | 15 | ✅ Yes |
| 16 | `admin_console` | `/admin` | admin | 16 | ❌ No |

### B.4 DependencyRegistry Graph (16 Edges)

```
profile ──────────────────────────────┐
  ├── farm_management (required)      │
  ├── marketplace (required)          │
  ├── financing (required)            │
  ├── logistics (required)            │
  ├── referral_hub (required)         │
  └── (no other module depends on it) │
                                      │
farm_management ──────────────────────┤
  ├── marketplace (optional)          │
  ├── analytics (required)            │
  ├── financing (optional)            │
  ├── traceability (required)         │
  └── carbon_credit (required)        │
                                      │
marketplace ──────────────────────────┘
  └── logistics (optional)
```

### B.5 Architecture Compliance ✓

| Rule | Status | Verification |
|------|--------|-------------|
| No runtime state | ✅ | All `static const` |
| No services/Supabase | ✅ | Zero imports from services/ |
| No UI/Flutter | ✅ | Zero Flutter imports |
| No async | ✅ | All synchronous |
| No providers | ✅ | Zero Riverpod imports |
| Pure lookups only | ✅ | `byId()`, `byRoute()`, `dependenciesOf()` — pure Dart |

---

## C. LAYER 2: MODULE RUNTIME DESCRIPTORS

### C.1 Core Model

**File**: `lib/core/composition/domain/models/module_descriptor.dart`  
**Purpose**: Pure data model for module runtime contributions. Every module exposes one descriptor.

**`ModuleRuntimeDescriptor`** carries 21 contribution types:

```
ModuleRuntimeDescriptor
├── dashboardWidgets        → DashboardWidgetDescriptor[]
├── homeWidgets             → HomeWidgetDescriptor[]
├── quickActions            → QuickActionDescriptor[]
├── notificationProviders   → NotificationProviderDescriptor[]
├── searchProviders         → SearchProviderDescriptor[]
├── analyticsProviders      → AnalyticsProviderDescriptor[]
├── routes                  → RouteDescriptor[]
├── permissions             → PermissionDescriptor[]
├── aiProviders             → AIProviderDescriptor[]          (Enterprise Phase)
├── commandPaletteActions   → CommandPaletteActionDescriptor[] (Enterprise Phase)
├── settingsPages           → SettingsPageDescriptor[]         (Enterprise Phase)
├── reports                 → ReportDescriptor[]               (Enterprise Phase)
├── backgroundJobs          → BackgroundJobDescriptor[]        (Enterprise Phase)
├── floatingActionButtons   → FloatingActionButtonDescriptor[] (Enterprise Phase)
├── exportProviders         → ExportProviderDescriptor[]       (Enterprise Phase)
├── importProviders         → ImportProviderDescriptor[]       (Enterprise Phase)
├── activityTimelineItems   → ActivityTimelineItemDescriptor[] (Enterprise Phase)
├── helpArticles            → HelpArticleDescriptor[]          (Enterprise Phase)
├── contextMenus            → ContextMenuDescriptor[]          (Enterprise Phase)
├── entityActions           → EntityActionDescriptor[]         (Enterprise Phase)
├── workflowSteps           → WorkflowStepDescriptor[]         (Enterprise Phase)
├── approvalActions         → ApprovalActionDescriptor[]       (Enterprise Phase)
└── shellExtensions         → ShellExtensionDescriptor[]
```

### C.2 Shell Extension Descriptor

Shell extensions allow modules to contribute widgets to shell slots **without the shell knowing what widget it is**.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique identifier for this extension |
| `slot` | `String` | Shell slot (matches `ShellExtensionSlot` enum: `appBar`, `statusBar`, `floatingActions`, `secondaryPanel`, `footer`) |
| `priority` | `int` | Ordering (lower = higher priority) |
| `featureFlagKey` | `String?` | Feature flag for governance |
| `requireModuleEnabled` | `bool` | Default: true |
| `hideInMaintenance` | `bool` | Default: true |

### C.3 Architecture Compliance ✓

| Rule | Status | Verification |
|------|--------|-------------|
| NO widget trees | ✅ | Descriptors carry ONLY metadata keys and configuration |
| NO rendering logic | ✅ | No build methods, no widgets, no providers |
| Pure data models | ✅ | All `const` constructors with optional defaults |

---

## D. LAYER 3: COMPOSITION ENGINE

### D.1 Location

**Path**: `lib/core/composition/`  
**Core File**: `lib/core/composition/engine/runtime_composition_engine.dart`

### D.2 Engine Architecture

```
RuntimeCompositionEngine
├── DependencyResolver      — resolves module dependency graph
├── ModuleAccessFilter      — applies Context Engine access filtering
├── ModuleToRuntimeMapper   — maps SystemModule → RuntimeModule
├── CompositionMetricsCollector — tracks metrics
└── Internal Cache          — cached RuntimeModule[] registry
```

### D.3 Core Pipeline

```dart
List<RuntimeModule> buildRegistry({
  required List<SystemModule> modules,
  required EntityContext context,
}) {
  // 1. Map SystemModules to RuntimeModules
  final runtimeModules = modules.map(...)...
  
  // 2. Apply Context Engine access filtering
  final filteredModules = _accessFilter.filterModules(
    modules: runtimeModules, context: context, metrics: _metrics,
  );

  // 3. Resolve dependencies (remove modules with missing deps)
  final resolvedModules = _dependencyResolver.resolveDependencies(
    filteredModules, metrics: _metrics,
  );

  // 4. Sort by display order (pinned first)
  resolvedModules.sort((a, b) { ... });

  // 5. Cache the result
  _cachedRegistry = resolvedModules;
}
```

### D.4 RuntimeModule Output Model

`RuntimeModule` is the **final output** after ALL governance and composition — carries 45+ resolved fields including:

- **Identifiers**: `moduleId`, `displayName`, `route`, `iconKey`, `displayOrder`
- **Visibility Flags**: `sidebarVisible`, `bottomNavVisible`, `dashboardVisible`, `quickActionVisible`, `launcherVisible`
- **State Flags**: `isEnabled`, `maintenanceMode`, `maintenanceMessage`
- **Grouping**: `section`, `category`, `group`, `parentModuleId`
- **Governance**: `premiumOnly`, `requiresSubscription`, `requiresEntity`, `requiresFarm`, `requiresBusiness`, `requiresVerification`
- **Capabilities**: `supportsGuest`, `supportsOffline`, `supportsSync`, `supportsSearch`, `supportsNotifications`
- **Observability**: `denialReason`

### D.5 Public Query Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getSidebarModules()` | `List<RuntimeModule>` | Module with `sidebarVisible = true` |
| `getBottomNavModules()` | `List<RuntimeModule>` | Modules with `bottomNavVisible = true` |
| `getDashboardModules()` | `List<RuntimeModule>` | Modules with `dashboardVisible = true` |
| `getQuickActionModules()` | `List<RuntimeModule>` | Modules with `quickActionVisible = true` |
| `getPinnedModules()` | `List<RuntimeModule>` | Pinned modules only |
| `getEnabledRoutes()` | `List<({String moduleId, String route})>` | Routes for all enabled modules |
| `isModuleEnabled()` | `bool` | Check single module |
| `getModuleById()` | `RuntimeModule?` | Single module lookup |

### D.6 Composition Providers

| Provider | File | Type | Description |
|----------|------|------|-------------|
| `runtimeModuleRegistryProvider` | `providers/composition_providers.dart` | `FutureProvider<List<RuntimeModule>>` | Full registry from composition engine |
| `enabledRuntimeModulesProvider` | `providers/composition_providers.dart` | `Provider<List<RuntimeModule>>` | Only enabled modules |
| `sidebarModulesProvider` | `providers/descriptor_providers.dart` | `Provider<List<RuntimeModule>>` | Sidebar-visible modules |
| `bottomNavModulesProvider` | `providers/descriptor_providers.dart` | `Provider<List<RuntimeModule>>` | Bottom nav-visible modules |
| `dashboardModulesProvider` | `providers/descriptor_providers.dart` | `Provider<List<RuntimeModule>>` | Dashboard-visible modules |
| `quickActionModulesProvider` | `providers/descriptor_providers.dart` | `Provider<List<RuntimeModule>>` | Quick action-visible modules |

---

## E. LAYER 4: GOVERNANCE & DECISION ENGINE

### E.1 Runtime Decision Engine

**File**: `lib/core/runtime_decision/application/runtime_decision_engine.dart`  
**Purpose**: SINGLE evaluation engine that combines EVERY governance layer into one final decision.

### E.2 Evaluation Order (MANDATORY — DO NOT CHANGE)

```
EntityContext
    ↓
1. CapabilityEngine    — "Does the org's plan support this feature?"
     ↓
2. PolicyEngine        — "Does the org's location policy allow this action?"
     ↓
3. AccessEngine        — "Does the user's role permit this operation?"
     ↓
4. RuntimeFeatureFlags — "Are the runtime flags enabled?"
     ↓
5. ALLOW / DENY with reason
```

### E.3 Decision Response Model

```dart
class RuntimeDecision {
  final bool allowed;
  final String reason;
  final String source;     // which layer denied
  final List<String> failedChecks;
}
```

### E.4 Convenience Methods

| Method | Returns | Usage |
|--------|---------|-------|
| `evaluate(RuntimeRequest)` | `RuntimeDecision` | Core — full evaluation |
| `canExecute(module, action)` | `bool` | "Can I run this workflow?" |
| `canRender(module, widget)` | `bool` | "Can I show this component?" |
| `canNavigate(module)` | `bool` | "Can I go to this screen?" |
| `canCreate(module)` | `bool` | "Can I create an item?" |
| `canEdit(module)` | `bool` | "Can I edit this item?" |
| `canDelete(module)` | `bool` | "Can I delete this item?" |
| `canApprove(module)` | `bool` | "Can I approve this workflow?" |
| `canPurchase(module)` | `bool` | "Can I buy?" |
| `canSell(module)` | `bool` | "Can I sell?" |
| `canExport(module)` | `bool` | "Can I export data?" |
| `canUpload(module)` | `bool` | "Can I upload files?" |
| `canViewAnalytics(module)` | `bool` | "Can I see analytics?" |
| `canUseAI(module)` | `bool` | "Can I use AI? (requires level ≥ 6)" |
| `canManageStaff(module)` | `bool` | "Can I manage staff?" |
| `canAccessWorkflow(module)` | `bool` | "Can I access workflows?" |

### E.5 Capability Engine

**File**: `lib/core/capabilities/application/capability_engine.dart`  
**Purpose**: Pure evaluation engine for organization capability profiles.

Key features:
- `hasCapability(id)` — O(1) cached lookup
- `getCapabilityLevel(id)` — returns 0 (disabled) through N
- `canAutomate(id)` — shorthand for level ≥ 5
- `canUseAI(id)` — shorthand for level ≥ 6
- `CapabilityRegistry.hasCapability(id)` — registration check

### E.6 Policy Engine

**File**: `lib/core/policies/application/policy_engine.dart`  
**Purpose**: Pure evaluation engine for location-based policies.

Typed accessors:
- `isAllowed(key)` / `getBoolean(key)` — boolean policy rules
- `getNumber(key)` — integer policy rules
- `getDecimal(key)` — double policy rules
- `getString(key)` — string policy rules
- `getList(key)` — list policy rules

### E.7 Access Decision Engine

**File**: `lib/core/access/access_decision_engine.dart`  
**Purpose**: Role + tier permission evaluation.

```dart
AccessDecision evaluate({
  required String featureKey,
  required String permission,
  required String role,
  required SubscriptionTier userTier,
});
```

Returns one of: `allow`, `deny`, `upgradeRequired`.

---

## F. LAYER 5: DASHBOARD RUNTIME ENGINE

### F.1 Location

**Path**: `lib/core/dashboard_engine/`  
**Core Exports**: `lib/core/dashboard_engine/engine.dart`

### F.2 Directory Structure

```
lib/core/dashboard_engine/
├── engine.dart                        ── Barrel export
├── bootstrap/
│   ├── dashboard_bootstrap.dart       ── ⚠️ DEAD CODE (see Issue #1)
│   └── dashboard_bootstrap_config.dart
├── domain/
│   ├── models/
│   │   ├── composition_node.dart
│   │   ├── dashboard_section.dart
│   │   ├── dashboard_widget_definition.dart
│   │   ├── layout_context.dart
│   │   ├── widget_identity.dart
│   │   └── widget_state_model.dart
│   ├── conflict/
│   ├── observability/
│   ├── prediction/
│   ├── recovery/
│   └── value_objects/
├── application/
│   ├── composition/              ── Composition snapshot, diff engine
│   ├── pipeline/                 ── Runtime pipeline orchestrator
│   │   └── stages/               ── Diff, Patch, Execution, Reconciliation
│   ├── reconciliation/           ── Dashboard runtime reconciler
│   ├── resolution/               ── Layout & widget resolution
│   ├── executor/                 ── Patch executor, retry orchestrator
│   ├── hydration/                ── Widget hydration engine
│   ├── conflict/                 ── Conflict buffer
│   ├── events/                   ── Dashboard event bus
│   ├── monitoring/               ── Watchdog, health snapshot
│   ├── observability/            ── Pipeline instrumentation
│   ├── providers/                ── 20+ providers
│   ├── state/                    ── Widget state store
│   ├── sequencing/               ── Event sequence tracker
│   ├── scheduler/                ── Frame scheduler
│   ├── prediction/               ── Predictive engine
│   ├── intelligence/             ── Widget scoring & usage tracking
│   ├── validation/               ── Runtime validator
│   └── workflow/                 ── Workflow engine
├── infrastructure/
│   ├── adapters/
│   ├── cache/
│   ├── checkpoint/
│   ├── journal/
│   ├── repositories/
│   ├── services/
│   └── sync/
└── presentation/
    ├── builders/                 ── Widget builder registry
    ├── observability/            ── Diagnostics overlay
    ├── pages/                    ── Dashboard pages
    ├── providers/                ── Dashboard UI providers
    ├── renderer/                 ── 🧠 Core renderer
    └── widgets/                  ── Zone, runtime health
```

### F.3 Pipeline Architecture

```
EventJournal (durable append-only log)
    │
    ▼
ConflictBuffer (in-memory ordering + staleness dedup)
    │
    ▼
RuntimePipelineOrchestrator
    │
    ├── ReconciliationStage ─── Coordinator bootstrap + state merge
    ├── DiffStage           ─── Diff generator (reconciler)
    ├── PatchStage          ─── Patch builder (reconciler)
    └── ExecutionStage      ─── Safe patch executor
    │
    ▼
ModuleRuntimeState (updated)
    │
    ▼
CheckpointStore (periodic materialized snapshots)
```

### F.4 Dashboard Renderer

**Files**: `lib/core/dashboard_engine/presentation/renderer/`

| Renderer | Purpose |
|----------|---------|
| `DashboardRenderer` | Abstract contract |
| `DashboardRendererWidget` | Base widget |
| `EnhancedDashboardRenderer` | Enhanced with animations |
| `RegistryDashboardRenderer` | Registry-backed |
| `ResponsiveDashboardRenderer` | Responsive layout |
| `FloatingActionButtonHost` | FAB management |

### F.5 Widget Registration

**Files**:
- `lib/core/dashboard_engine/presentation/builders/widget_builder_registry.dart` — Central registry
- `lib/core/dashboard_engine/presentation/builders/widget_registry.dart` — Widget registry container
- `lib/core/dashboard_engine/presentation/builders/widget_builder_resolver.dart` — Key → widget builder resolver
- `lib/core/dashboard_engine/presentation/builders/widget_registration_bootstrap.dart` — Bootstrap registration
- `lib/core/dashboard_engine/presentation/builders/phase_d_widget_bootstrap.dart` — Phase D bootstrap

### F.6 Key Providers (20+)

| Provider | Type | Purpose |
|----------|------|---------|
| `dashboardProvider` | Provider | Dashboard state |
| `dashboardRendererProvider` | Provider | Current renderer |
| `dashboardFrameSchedulerProvider` | Provider | Frame scheduling |
| `dashboardRuntimePatchProvider` | Provider | Runtime patches |
| `dashboardRuntimeValidatorProvider` | Provider | Validation |
| `dashboardRuntimeWatchdogProvider` | Provider | Health watchdog |
| `dashboardHealthSnapshotProvider` | Provider | Health metrics |
| `widgetStateProvider` | Provider | Widget state |
| `widgetHydrationProvider` | Provider | Hydration |
| `workflowEngineProvider` | Provider | Workflow execution |
| `providerHealthMonitor` | Provider | Provider diagnostics |
| `retryOrchestratorProvider` | Provider | Retry logic |
| `safeDashboardPatchExecutorProvider` | Provider | Safe execution |
| `dashboardPatchExecutorProvider` | Provider | Patch execution |
| `moduleDegradationProvider` | Provider | Degradation state |
| `traceCollectorProvider` | Provider | Trace collection |
| `auditLogProvider` | Provider | Audit logging |
| `observabilityProviders` | Provider | Observability |
| `runtimeMetricsCollector` | Provider | Metrics |

---

## G. LAYER 6: RUNTIME SYNC ENGINE

### G.1 Location

**File**: `lib/core/module_runtime_sync/runtime_sync_engine.dart`

### G.2 Architecture

```
RuntimeSyncEngine
├── Initialization pipeline
│   ├── coordinator.bootstrap()
│   ├── persistenceStore.initialize()
│   ├── checkpoint restore
│   ├── widget state hydration (non-critical)
│   └── delta replay (adaptive batching)
│
├── Real-time subscriptions
│   ├── system.modules (Postgres changes)
│   └── system.module_installations (Postgres changes)
│
├── Event ingestion pipeline
│   ├── ConflictBuffer (with capacity controls)
│   ├── Coalescing window (32ms)
│   └── Pipeline orchestrator
│
├── Persistence
│   ├── EventJournal (append-only log)
│   ├── CheckpointStore (periodic snapshots)
│   └── Journal compaction
│
└── Lifecycle
    ├── Reconnect backoff (exponential)
    ├── Background throttling
    └── Graceful shutdown with final checkpoint
```

### G.3 Phase 6 Enhancements (Implemented)

| Task | Feature | Implementation |
|------|---------|---------------|
| A1 | Event coalescing window | `Timer(32ms)` — batch processing |
| A2 | Adaptive replay batch sizing | Large backlog → smaller batches to prevent UI freeze |
| A3 | ConflictBuffer capacity controls | 500 max buffered, 5000 max replay, overflow diagnostics |
| B2 | Runtime memory metrics | Event counts, pipeline runs, buffer utilization |
| C1 | Diff short-circuiting | Skip pipeline when no meaningful changes |
| D1 | Recovery metrics | Replayed count, checkpoint/journal durations |
| D2 | Structured trace IDs | `rte-{N}` end-to-end |
| D3 | Runtime health status | Healthy / replaying / degraded / overflow |
| E1 | Reconnect backoff | Exponential 1s → 30s max |
| E3 | Background throttling | Queue events when app is backgrounded |
| G2 | Feature flags for runtime controls | Checkpointing, compaction, replay metrics, adaptive batching |

### G.4 Runtime Health Status

```dart
enum RuntimeHealthStatus {
  healthy,
  replaying,
  degraded,    // buffer near capacity
  overflow,    // buffer at max capacity
}
```

---

## H. CROSS-CUTTING: EVENT BUS & WORKFLOW ORCHESTRATOR

### H.1 AppEventBus (Singleton)

**File**: `lib/core/events/app_event_bus.dart`

```dart
class AppEventBus {
  static final AppEventBus instance = AppEventBus._internal();
  
  void emit(AppEvent event);
  Stream<AppEvent> listen(void Function(AppEvent) onEvent);
  Stream<T> on<T extends AppEvent>();
  StreamSubscription<T> subscribe<T extends AppEvent>(void Function(T));
  void dispose();
}
```

### H.2 Event Taxonomy

| Event | File | Type | Purpose |
|-------|------|------|---------|
| `ModuleUpdatedEvent` | `events.dart` | Module event | A module definition changed |
| `ModuleInstalledEvent` | `events.dart` | Module event | A new module was installed |
| `DashboardPatchEvent` | `events.dart` | Dashboard event | Patch produced by pipeline (carries ONLY `patchId` — no domain objects) |
| `RuntimeSyncEvent` | `events.dart` | Runtime event | Runtime sync signal |
| `SystemBootEvent` | `events.dart` | System event | System boot completed |
| `SystemErrorEvent` | `events.dart` | System event | System error reported |
| `WorkflowEvent` | `workflow_events.dart` | Workflow event | Workflow step triggered/completed |

### H.3 Workflow Event System

**File**: `lib/core/events/workflow_events.dart`  
**Purpose**: Event-based workflow orchestration seed (GAP-CLOSURE for G8: "No formalized cross-module workflow engine")

**Layers**:
1. Workflow Event Definitions (this file)
2. Workflow Definitions (future)
3. Workflow Engine (future)

**Key Types**:
- `WorkflowEvent` — emitted when a workflow step is triggered/completed
- `WorkflowStep` — a single step with dependencies, timeout, optional flag
- `WorkflowDefinition` — ordered steps + metadata
- `WorkflowState` — runtime tracking for active workflows

### H.4 WorkflowOrchestrator

**File**: `lib/core/events/workflow_orchestrator.dart`  
**Purpose**: Bridges workflow events → provider state updates.

**Configured workflow bridges** (in `lib/main.dart`):
- `kpi_automation` → `farmDashboardProvider.notifier().refreshKpi()`
- `stock_mutation` → `assetsProvider.notifier().refreshAssets()`
- `production_publish` → `marketplaceProvider.notifier().refreshListings()`
- `production_to_marketplace` → `marketplaceProvider.notifier().refreshListings()`

---

## I. DATA FLOW END-TO-END WALKTHROUGH

### I.1 Module Registration → Dashboard Rendering

```
Step 1: Bootstrap (main.dart)
        │
        ├── bootstrapModulePageBuilders()     ── Registers page builders (16 modules + 6 system)
        ├── bootstrapModuleDescriptors()      ── Creates ModuleRuntimeDescriptor (15 modules)
        ├── bootstrapModuleContributions()    ── Bridges → ContributionRegistry (21 types)
        └── bootstrapPhaseD()                 ── Widget registrations, search, AI, reports, observability

Step 2: First frame (MyApp.build())
        │
        └── runtimeModuleRegistryProvider (watched)
                │
                ├── moduleProvider.fetchActiveModules() ── Supabase: system.modules
                ├── contextProvider (for EntityContext)
                └── RuntimeCompositionEngine.buildRegistry()
                        │
                        ├── SystemModule → RuntimeModule (mapper)
                        ├── ModuleAccessFilter (context-based)
                        ├── DependencyResolver (graph)
                        └── Cached registry

Step 3: Shell renders
        │
        ├── SidebarModulesProvider  → sidebar rendering
        ├── BottomNavModulesProvider → bottom nav rendering
        └── DashboardModulesProvider → dashboard sections

Step 4: Dashboard composition
        │
        ├── DashboardCompositionEngine
        ├── WidgetResolutionEngine
        ├── LayoutResolver
        └── DashboardRenderer

Step 5: User interacts → RuntimeSyncEngine captures changes
        │
        ├── EventJournal (append)
        ├── ConflictBuffer (resolve)
        ├── Pipeline (reconcile → diff → patch → execute)
        └── CheckpointStore (periodic snapshot)
```

### I.2 Governance Evaluation (Single Request)

```
User clicks "Execute" on Workflow module
        │
        ▼
RuntimeDecisionEngine.evaluate(RuntimeRequest(
  action: 'execute',
  module: 'workflow',
  capability: 'workflow.execute',
  policy: 'workflow.execution',
  permission: 'workflow.execute',
  featureFlag: 'workflow_enabled',
))
        │
        ├── CapabilityEngine.hasCapability('workflow.execute')
        │     └── Checks CapabilityRegistry + OrganizationProfile
        │         └── If denied → { allowed: false, source: capabilityEngine }
        │
        ├── PolicyEngine.isAllowed('workflow.execution')
        │     └── Checks EffectivePolicy.rules map
        │         └── If denied → { allowed: false, source: policyEngine }
        │
        ├── AccessDecisionEngine.evaluate(permission, role, tier)
        │     └── Checks AccessPolicy.rolePermissions + featureTiers
        │         └── If denied → { allowed: false, source: accessEngine }
        │
        ├── Feature flag check
        │     └── Checks runtimeFlags map + guest/entity/tier
        │         └── If denied → { allowed: false, source: featureFlags }
        │
        └── ALLOW → { allowed: true }
```

---

## J. ARCHITECTURE COMPLIANCE MATRIX

### J.1 Layer Separation

| Layer | Directory | Imports From | Imports To |
|-------|-----------|--------------|------------|
| **Layer 1** — Static Registries | `system/registry/` | `registry_contracts.dart` only | ✅ Nothing below |
| **Layer 2** — Descriptors | `features/*/bootstrap/` | Descriptor model | ✅ Layer 1 |
| **Layer 3** — Composition | `core/composition/` | Layer 1 + Layer 2 + Context Engine | ✅ Dashboard Engine |
| **Layer 4** — Governance | `core/runtime_decision/` | Capability + Policy + Access + Flags | ✅ Composition |
| **Layer 5** — Dashboard | `core/dashboard_engine/` | Composition + Runtime Sync | ✅ Presentation |
| **Layer 6** — Runtime Sync | `core/module_runtime_sync/` | Dashboard Engine + Supabase | ✅ Dashboard Engine |

### J.2 RuntimeModule vs ModuleRuntimeDescriptor

| Aspect | RuntimeModule (Composition) | ModuleRuntimeDescriptor (Contribution) |
|--------|----------------------------|----------------------------------------|
| Location | `core/composition/domain/models/` | `core/composition/domain/models/` |
| Created by | `RuntimeCompositionEngine.buildRegistry()` | Feature modules at bootstrap |
| Mutability | Immutable after creation | Immutable constant |
| Contains | Resolved governance + visibility + state | Contribution metadata + widget keys |
| Used by | Shell, Navigation, Dashboard, Providers | ContributionEngine