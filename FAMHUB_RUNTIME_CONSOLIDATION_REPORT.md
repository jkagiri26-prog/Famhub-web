# FAMHUB Runtime Consolidation Report

**Date**: June 2026  
**Audit Scope**: Complete runtime architecture across `lib/core/`, `lib/system/`, `lib/app/`, `lib/features/`  
**Status**: PHASE 1–6 Complete — No code modifications  

---

## PHASE 1 — RUNTIME INVENTORY

### 1.1 Core Runtime Subsystems

| # | Subsystem | Location | Purpose | Dependencies | Used By | Status | Replacement Candidate? |
|---|-----------|----------|---------|-------------|---------|--------|----------------------|
| R1 | **RuntimeSyncEngine** | `lib/core/module_runtime_sync/runtime_sync_engine.dart` | Event-sourced state sync: journal, checkpoint, conflict buffer, pipeline orchestration | Supabase, Coordinator, PersistenceStore, Dashboard reconciler/diff/patch/executor | `main.dart` startup, runtime state mgmt, realtime subscriptions | **ACTIVE** | No — core sync layer |
| R2 | **RuntimeCompositionEngine** | `lib/core/composition/engine/runtime_composition_engine.dart` | Full pipeline: fetch → filter → resolve dependencies → map → output. Builds RuntimeModuleRegistry | DependencyResolver, ModuleAccessFilter, ModuleToRuntimeMapper, SystemModule list, EntityContext | Shell, Dashboard, Navigation, Sidebar, Providers | **ACTIVE** | No — core composition |
| R3 | **DashboardEngine** | `lib/core/dashboard_engine/` | Dashboard runtime: composition engine, reconciliation, diff/patch/executor pipeline, widget hydration, observability, checkpointing, event journal | Composition engine, widget registry, widget store, providers | Shell `UnifiedDashboardHost`, renderers, providers | **ACTIVE** | No — core dashboard |
| R4 | **WorkspaceEngine** | `lib/core/workspace/application/workspace_engine.dart` | Tab management, navigation history, sidebar state, workspace lifecycle, persistence | WorkspaceStorage (I/O) | Shell, Tab UI, providers | **ACTIVE** | No — core workspace |
| R5 | **CapabilityEngine** | `lib/core/capabilities/application/capability_engine.dart` | Organization capability evaluation (level-based). Pure O(1) lookup | CapabilityProfile, CapabilityRegistry | RuntimeDecisionEngine, providers, feature gates | **ACTIVE** | No — core governance |
| R6 | **PolicyEngine** | `lib/core/policies/application/policy_engine.dart` | Location/region policy evaluation. Pure O(1) map lookup | EffectivePolicy, PolicyRuleRegistry | RuntimeDecisionEngine, providers | **ACTIVE** | No — core governance |
| R7 | **AccessDecisionEngine** | `lib/core/access/access_decision_engine.dart` | Role + tier-based access evaluation | AccessPolicy, SubscriptionTier, Ref | RuntimeDecisionEngine, guards | **ACTIVE** | No — core governance |
| R8 | **RuntimeDecisionEngine** | `lib/core/runtime_decision/application/runtime_decision_engine.dart` | Unified evaluator: combines capability + policy + access + feature flags into one decision | CapabilityEngine, PolicyEngine, AccessDecisionEngine, EntityContext, RuntimeFeatureFlags | All widgets, providers, services via `canExecute()`/`canRender()` etc. | **ACTIVE** | No — core governance |
| R9 | **OrganizationRuntime** | `lib/core/organization_runtime/` | Organization context resolution, active org provider, bridges | EntityContext | CapabilityEngine, PolicyEngine, RuntimeDecisionEngine, providers | **ACTIVE** | No — core organization |
| R10 | **ContextEngine** | `lib/core/context_engine/` | Entity context resolution, role context, sync services | Supabase, storage | All runtime engines, providers | **ACTIVE** | No — core context |
| R11 | **AppEventBus** | `lib/core/events/app_event_bus.dart` | System-wide broadcast event bus (singleton, StreamController-based) | None (pure Dart) | Module events, dashboard patches, runtime sync, system events, workflow events | **ACTIVE** | See Phase 3 — potential duplicate |
| R12 | **DashboardEventBus** | `lib/core/dashboard_engine/application/events/dashboard_event_bus.dart` | Dashboard-specific event bus | AppEvent (base) | Dashboard composition, mapping sync | **ACTIVE** | See Phase 3 — potential duplicate |
| R13 | **MappingSyncEventBus** | `lib/core/dashboard_engine/application/events/mapping_sync_event_bus.dart` | Module-zone mapping synchronization events | AppEvent (base) | Dashboard mapping engine | **ACTIVE** | See Phase 3 — potential duplicate |
| R14 | **WorkflowOrchestrator** | `lib/core/events/workflow_orchestrator.dart` | Event-to-provider binding for cross-module workflows | AppEventBus, feature-specific providers | Startup bootstrap | **ACTIVE** | See Phase 3 — potential duplicate |

### 1.2 SDK Layer

| # | SDK | Location | Purpose | Dependencies | Used By | Status |
|---|-----|----------|---------|-------------|---------|--------|
| S1 | **famhub_sdk** | `lib/core/sdk/famhub_sdk.dart` | Aggregate SDK facade | All sub-SDKs | External consumers, modules | **ACTIVE** |
| S2 | **access_sdk** | `lib/core/sdk/access_sdk.dart` | Access control API | AccessDecisionEngine | Feature modules | **ACTIVE** |
| S3 | **ai_context_sdk** | `lib/core/sdk/ai_context_sdk.dart` | AI context provider SDK | AI context services | AI features | **ACTIVE** |
| S4 | **capability_sdk** | `lib/core/sdk/capability_sdk.dart` | Capability check API | CapabilityEngine | Feature modules | **ACTIVE** |
| S5 | **dashboard_sdk** | `lib/core/sdk/dashboard_sdk.dart` | Dashboard composition API | DashboardEngine | Feature modules | **ACTIVE** |
| S6 | **navigation_sdk** | `lib/core/sdk/navigation_sdk.dart` | Navigation/routing API | Router, Nav services | Feature modules | **ACTIVE** |
| S7 | **notification_sdk** | `lib/core/sdk/notification_sdk.dart` | Notification API | NotificationService | Feature modules | **ACTIVE** |
| S8 | **organization_sdk** | `lib/core/sdk/organization_sdk.dart` | Organization context API | OrganizationRuntime | Feature modules | **ACTIVE** |
| S9 | **policy_sdk** | `lib/core/sdk/policy_sdk.dart` | Policy evaluation API | PolicyEngine | Feature modules | **ACTIVE** |
| S10 | **shell_sdk** | `lib/core/sdk/shell_sdk.dart` | Shell extension API | Shell config, ShellExtensionProvider | Feature modules, extensions | **ACTIVE** |
| S11 | **spatial_sdk** | `lib/core/sdk/spatial_sdk.dart` | Spatial/geolocation API | SpatialEngine | Spatial features | **ACTIVE** |
| S12 | **workflow_sdk** | `lib/core/sdk/workflow_sdk.dart` | Workflow execution API | WorkflowDefinitions | Feature modules | **ACTIVE** |
| S13 | **workspace_sdk** | `lib/core/sdk/workspace_sdk.dart` | Workspace/tab management API | WorkspaceEngine | Feature modules | **ACTIVE** |
| S14 | **sdk_api_guard** | `lib/core/sdk/api/sdk_api_guard.dart` | SDK usage guard/decorator | None | All SDK consumers | **ACTIVE** |
| S15 | **sdk_contract** | `lib/core/sdk/api/sdk_contract.dart` | SDK contract/base class | None | All SDK implementations | **ACTIVE** |
| S16 | **sdk_version** | `lib/core/sdk/api/sdk_version.dart` | SDK versioning metadata | None | All SDK consumers | **ACTIVE** |

### 1.3 Registry Layer

| # | Registry | Location | Purpose | Dependencies | Used By | Status |
|---|----------|----------|---------|-------------|---------|--------|
| G1 | **ModuleRegistry** | `lib/system/registry/module_registry.dart` | Static module blueprint definitions (16 modules) | RegistryContracts | CompositionEngine, services, dashboard | **ACTIVE** |
| G2 | **DependencyRegistry** | `lib/system/registry/dependency_registry.dart` | Static module dependency graph | RegistryContracts | DependencyResolver, CompositionEngine | **ACTIVE** |
| G3 | **FeatureRegistry** | `lib/system/registry/feature_registry.dart` | Feature defnitions per module | RegistryContracts | Access control, feature flags | **ACTIVE** |
| G4 | **RouteRegistry** | `lib/system/registry/route_registry.dart` | Route mappings per module | RegistryContracts | Router, DynamicRouteRegistrar | **ACTIVE** |
| G5 | **AccessRegistry** | `lib/system/registry/access_registry.dart` | Access rule definitions (roles, tiers) | RegistryContracts | AccessDecisionEngine | **ACTIVE** |
| G6 | **RegistryContracts** | `lib/system/registry/registry_contracts.dart` | Shared blueprint types | None (pure Dart) | All registries | **ACTIVE** |
| G7 | **CapabilityRegistry** | `lib/core/capabilities/registry/capability_registry.dart` | Capability ID → level definitions | Domain models | CapabilityEngine | **ACTIVE** |
| G8 | **PolicyRuleRegistry** | `lib/core/policies/registry/policy_rule_registry.dart` | Policy rule key definitions | Domain models | PolicyEngine | **ACTIVE** |
| G9 | **WidgetBuilderRegistry** | `lib/core/dashboard_engine/presentation/builders/widget_builder_registry.dart` | Widget builder key → builder function map | Flutter widgets | DashboardRenderer | **ACTIVE** |
| G10 | **WidgetRegistry** | `lib/core/dashboard_engine/presentation/builders/widget_registry.dart` | Widget metadata registry | None | WidgetBuilderResolver | **ACTIVE** |
| G11 | **ModuleDescriptorRegistry** | `lib/core/composition/domain/models/module_descriptor_registry.dart` | ModuleRuntimeDescriptor collection | ModuleRuntimeDescriptor | ContributionEngine, CompositionEngine | **ACTIVE** |
| G12 | **ContributionRegistry** | `lib/core/composition/contributions/contribution_registry.dart` | Contribution type → list of contributions | Contribution models | Shell, Dashboard, Navigation | **ACTIVE** |
| G13 | **SectionRegistry** | `lib/core/composition/domain/models/section_registry.dart` | Dashboard section definitions | None | Dashboard composition | **ACTIVE** |

### 1.4 Bootstrap / Startup Layer

| # | Component | Location | Purpose | Dependencies | Used By | Status |
|---|-----------|----------|---------|-------------|---------|--------|
| B1 | **main.dart** | `lib/main.dart` | Application entry: error handling, Supabase init, ProviderContainer, bootstrap calls | All startup components | — | **ACTIVE** |
| B2 | **bootstrap.dart** | `lib/app/bootstrap.dart` | Bootstrap documentation (deferred to main.dart) | None | Documentation | **ACTIVE** |
| B3 | **app_initializer** | `lib/app/app_initializer.dart` | App initialization orchestration | ProviderContainer | main.dart | **ACTIVE** |
| B4 | **app_entry** | `lib/app/app_entry.dart` | App entry widget | None | main.dart | **ACTIVE** |
| B5 | **app.dart** | `lib/app/app.dart` | MyApp widget, theme, router setup | Context provider, router provider, theme provider | main.dart | **ACTIVE** |
| B6 | **capability_bootstrap** | `lib/core/capabilities/bootstrap/capability_bootstrap.dart` | Capability system initialization | CapabilityRegistry | Startup | **ACTIVE** |
| B7 | **policy_bootstrap** | `lib/core/policies/bootstrap/policy_bootstrap.dart` | Policy system initialization | PolicyRuleRegistry | Startup | **ACTIVE** |
| B8 | **contribution_bootstrap** | `lib/core/composition/bootstrap/contribution_bootstrap.dart` | Contribution descriptor → contribution registration | DescriptorRegistry, ContributionRegistry | Startup | **ACTIVE** |
| B9 | **module_descriptor_bootstrap** | `lib/core/composition/bootstrap/module_descriptor_bootstrap.dart` | Module descriptor registration | ModuleDescriptorRegistry | Startup (called in main.dart) | **ACTIVE** |
| B10 | **spatial_bootstrap** | `lib/core/spatial/bootstrap/spatial_bootstrap.dart` | Spatial engine initialization | Spatial repository | Startup | **ACTIVE** |
| B11 | **dashboard_bootstrap** | `lib/core/dashboard_engine/bootstrap/dashboard_bootstrap.dart` | Dashboard initialization (widget builders, etc.) | WidgetBuilderRegistry | Startup — **BUT NEVER CALLED** | **DEAD** |
| B12 | **phase_d_dashboard_bootstrap** | `lib/core/dashboard_engine/presentation/builders/phase_d_dashboard_bootstrap.dart` | Phase D dashboard widget registration | WidgetBuilderRegistry | Startup (called in main.dart) | **ACTIVE** |
| B13 | **phase_d_widget_bootstrap** | `lib/core/dashboard_engine/presentation/builders/phase_d_widget_bootstrap.dart` | Phase D widget bootstrap | UI components | main.dart | **ACTIVE** |
| B14 | **widget_registration_bootstrap** | `lib/core/dashboard_engine/presentation/builders/widget_registration_bootstrap.dart` | Widget registration initialization | WidgetBuilderRegistry | main.dart | **ACTIVE** |
| B15 | **startup_coordinator** | `lib/core/startup/startup_coordinator.dart` | Startup coordination helpers | None | main.dart | **ACTIVE** |

### 1.5 Provider / State Layer

| # | Component | Location | Count | Purpose |
|---|-----------|----------|-------|---------|
| P1 | **Dashboard providers** | `lib/core/dashboard_engine/application/providers/` | 16+ | Frame scheduler, health snapshot, patch executor, renderer, runtime patch, validator, watchdog, module degradation, observability, retry orchestrator, safe executor, trace collector, widget hydration, widget state, workflow engine |
| P2 | **Composition providers** | `lib/core/composition/providers/` | 3 | Composition state, contributions, descriptors |
| P3 | **Capability providers** | `lib/core/capabilities/application/` | 2 | Capability engine, capability profile |
| P4 | **Policy providers** | `lib/core/policies/application/` | 2 | Policy engine, effective policy |
| P5 | **Workspace providers** | `lib/core/workspace/application/` | 2 | Workspace provider, active workspace |
| P6 | **Runtime decision providers** | `lib/core/runtime_decision/application/` | 1 | Runtime decision provider |
| P7 | **Context providers** | `lib/core/providers/` | 14+ | Auth, module, notification, sync state, system state, theme, user, location, carbon, connectivity |
| P8 | **Organization runtime providers** | `lib/core/organization_runtime/application/` | 2 | Organization runtime, active organization |
| P9 | **Module runtime sync providers** | `lib/core/module_runtime_sync/application/providers/` | 1 | Module runtime sync state |
| P10 | **Module providers** | `lib/core/modules/application/providers/` | 1 | Module repository |
| P11 | **Feature flags providers** | `lib/core/feature_flags/application/providers/` | 4 | Access state, feature access, governance, module state, runtime flags |

### 1.6 Shell / Presentation Layer

| # | Component | Location | Purpose | Status |
|---|-----------|----------|---------|--------|
| H1 | **UnifiedDashboardHost** | `lib/core/shell/presentation/regions/unified_dashboard_host.dart` | Primary runtime surface — orchestrates composition | **ACTIVE** |
| H2 | **UnifiedAppShellV2** | `lib/core/shell/presentation/pages/new_unified_app_shell.dart` | Main app shell with regions | **ACTIVE** |
| H3 | **ShellLayouts** (5 layouts) | `lib/core/shell/presentation/layouts/` | Responsive layout variants (compact, mobile, tablet, desktop, ultraWide) | **ACTIVE** |
| H4 | **ShellRegions** (7 regions) | `lib/core/shell/presentation/regions/` | App bar, floating actions, footer, secondary panel, status bar, dashboard host | **ACTIVE** |
| H5 | **DashboardRenderers** (5 renderers) | `lib/core/dashboard_engine/presentation/renderer/` | dashboard_renderer, enhanced, responsive, registry, FAB host | **ACTIVE** |
| H6 | **Observability UI** | `lib/core/dashboard_engine/presentation/observability/` | Diagnostics overlay, metrics panel, pipeline timing, replay monitor | **ACTIVE** |

### 1.7 Observability / Monitoring

| # | Component | Location | Purpose | Status |
|---|-----------|----------|---------|--------|
| O1 | **RuntimeMetricsCollector** | `lib/core/dashboard_engine/application/observability/runtime_metrics_collector.dart` | Comprehensive runtime metrics | **ACTIVE** |
| O2 | **DashboardRuntimeWatchdog** | `lib/core/dashboard_engine/application/monitoring/dashboard_runtime_watchdog.dart` | Health monitoring & health snapshots | **ACTIVE** |
| O3 | **TraceCollector** | `lib/core/dashboard_engine/application/telemetry/trace_collector.dart` | Dashboard trace event collection | **ACTIVE** |
| O4 | **EventObserver** | `lib/core/observability/event_observer.dart` | System-wide event observation | **ACTIVE** |
| O5 | **EventJournal** | `lib/core/dashboard_engine/infrastructure/journal/event_journal.dart` | Durable event log | **ACTIVE** |
| O6 | **RuntimeCheckpointStore** | `lib/core/dashboard_engine/infrastructure/checkpoint/runtime_checkpoint_store.dart` | State checkpoint persistence | **ACTIVE** |
| O7 | **ProviderHealthMonitor** | `lib/core/dashboard_engine/application/providers/provider_health_monitor.dart` | Provider health tracking | **ACTIVE** |
| O8 | **PipelineInstrumentation** | `lib/core/dashboard_engine/application/observability/pipeline_instrumentation_adapter.dart` | Pipeline timing instrumentation | **ACTIVE** |
| O9 | **AuditLogSink** | `lib/core/dashboard_engine/application/observability/audit_log_sink.dart` | Audit log sink | **ACTIVE** |

### 1.8 Spatial Engine

| # | Component | Location | Purpose | Status |
|---|-----------|----------|---------|--------|
| SP1 | **SpatialEngine** | `lib/core/spatial/application/spatial_engine.dart` | Spatial/geospatial operations | **ACTIVE** |
| SP2 | **SpatialSDK** | `lib/core/spatial/sdk/spatial_sdk.dart` | Spatial API for modules | **ACTIVE** |
| SP3 | **SpatialCompositionBridge** | `lib/core/spatial/composition/spatial_composition_bridge.dart` | Bridge spatial to composition | **ACTIVE** |
| SP4 | **SpatialBootstrap** | `lib/core/spatial/bootstrap/spatial_bootstrap.dart` | Spatial initialization | **ACTIVE** |

---

## PHASE 2 — RUNTIME MAP (Architecture Diagram)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           FAMHUB RUNTIME ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                        STARTUP BOOTSTRAP                         │    │
│  │  main.dart → configureGlobalErrorHandling() → Supabase.init()    │    │
│  │  → ProviderContainer → RuntimeSyncEngine (constructor)           │    │
│  │  → WorkflowOrchestrator → 4x bootstrap* calls → runApp()        │    │
│  │  → [deferred] ContextController.init() + RuntimeSyncEngine.init()│    │
│  └──────────┬──────────────────────────────────────────────────────┘    │
│             │                                                            │
│             ▼                                                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    SYSTEM REGISTRIES (STATIC)                     │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────┐  │    │
│  │  │  Module  │ │  Dep     │ │  Feature │ │  Route   │ │Access │  │    │
│  │  │ Registry │ │ Registry │ │ Registry │ │ Registry │ │Registry│  │    │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬───┘  │    │
│  │  ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐     │            │      │    │
│  │  │  Capability│  │Policy   │  │Widget   │     │            │      │    │
│  │  │  Registry  │  │Registry │  │Registries│    │            │      │    │
│  │  └──────────┘ └──────────┘ └──────────┘    │            │      │    │
│  └────────────────────────────────┬────────────────────────────────┘    │
│                                   │                                      │
│                                   ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    CORE ENGINES (LAYER 1)                        │    │
│  │                                                                  │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │    │
│  │  │  Context Engine  │  │ Organization    │  │  Capability     │  │    │
│  │  │  (context_engine)│─▶│ Runtime          │─▶│  Engine         │  │    │
│  │  └─────────────────┘  └─────────────────┘  └────────┬────────┘  │    │
│  │                                                      │            │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌────────▼────────┐  │    │
│  │  │  Policy Engine   │  │ Access Decision │  │  Runtime        │  │    │
│  │  │  (policies)      │─▶│ Engine (access) │─▶│  Feature Flags  │  │    │
│  │  └─────────────────┘  └─────────────────┘  └────────┬────────┘  │    │
│  │                                                      │            │    │
│  └──────────────────────────────────────────────────────┼─────────────┘    │
│                                                         │                  │
│                                                         ▼                  │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                   RUNTIME DECISION ENGINE (UNIFIED)              │    │
│  │  Combines: Capability + Policy + Access + Feature Flags         │    │
│  │  Exposes: canExecute() canRender() canNavigate() canApprove()   │    │
│  │  Pattern: All governance → ONE decision                        │    │
│  └────────────────────────┬────────────────────────────────────────┘    │
│                           │                                              │
│                           ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    COMPOSITION LAYER (LAYER 2)                    │    │
│  │                                                                  │    │
│  │  ┌─────────────────────────────────────────────────────────┐    │    │
│  │  │           RUNTIME COMPOSITION ENGINE                      │    │    │
│  │  │  Pipeline: fetch modules → filter (access/deps) → sort   │    │    │
│  │  │  → resolve widget builders → cache RuntimeModule[]       │    │    │
│  │  │  Output: RuntimeModuleRegistry (enabled modules only)     │    │    │
│  │  └──────────┬──────────┬──────────┬──────────┬──────────────┘    │    │
│  │             │          │          │          │                    │    │
│  │             ▼          ▼          ▼          ▼                    │    │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐          │    │
│  │  │ Nav  │ │Sidebar│ │Bottom│ │Quick │ │Pinned│ │ Dash │          │    │
│  │  │Routes│ │Modules│ │ Nav  │ │Actions│ │Mods  │ │board │          │    │
│  │  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──┬───┘          │    │
│  │                                                    │              │    │
│  └────────────────────────────────────────────────────┼───────────────┘    │
│                                                       │                    │
│                                                       ▼                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │              DASHBOARD ENGINE (LAYER 3)                          │    │
│  │                                                                  │    │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐   │    │
│  │  │ Composition Eng  │  │ Reconciler (Diff │  │  Patch       │   │    │
│  │  │ (layout/section) │─▶│ /Patch/Exec)      │─▶│  Executor    │   │    │
│  │  └──────────────────┘  └────────┬─────────┘  └──────┬───────┘   │    │
│  │                                 │                    │           │    │
│  │  ┌──────────────────┐  ┌───────▼─────────┐  ┌───────▼───────┐   │    │
│  │  │ Widget Hydration  │  │ Diff Engine     │  │ Pipeline      │   │    │
│  │  └──────────────────┘  └─────────────────┘  │ Orchestrator  │   │    │
│  │                                              └───────────────┘   │    │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐   │    │
│  │  │ Renderer Service  │  │ Layout Resolver  │  │ Widget       │   │    │
│  │  └──────────────────┘  └──────────────────┘  │ Scoring      │   │    │
│  │                                              └──────────────┘   │    │
│  └──────────────────────┬───────────────────────────────────────────┘    │
│                         │                                                │
│                         ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │               SHELL & PRESENTATION (LAYER 4)                     │    │
│  │                                                                  │    │
│  │  ┌─────────────────────────────────────────────────────────┐    │    │
│  │  │            UnifiedAppShellV2                             │    │    │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │    │    │
│  │  │  │ App Bar  │ │ Sidebar │ │ Main     │ │ Secondary│   │    │    │
│  │  │  │ Region   │ │ Region  │ │ Content  │ │ Panel    │   │    │    │
│  │  │  └──────────┘ └──────────┘ │ Region   │ └──────────┘   │    │    │
│  │  │                            └──────────┘                │    │    │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────────┐            │    │    │
│  │  │  │ Footer   │ │ Status   │ │ Floating     │            │    │    │
│  │  │  │ Region   │ │ Bar      │ │ Action Host  │            │    │    │
│  │  │  └──────────┘ └──────────┘ └──────────────┘            │    │    │
│  │  └─────────────────────────────────────────────────────────┘    │    │
│  │                           │                                      │    │
│  │                           ▼                                      │    │
│  │  ┌─────────────────────────────────────────────────────────┐    │    │
│  │  │            UnifiedDashboardHost                          │    │    │
│  │  │  (Runtime Surface — orchestrates zone rendering)         │    │    │
│  │  │  → Consumes dashboardProvider → delegates to renderer    │    │    │
│  │  └─────────────────────────────────────────────────────────┘    │    │
│  │                                                                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │              WORKSPACE ENGINE (LAYER 2.5)                        │    │
│  │  Tab management, nav history, sidebar state, workspace lifecycle │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │    │
│  │  │ Tab Ops  │ │ History  │ │ Sidebar  │ │ Persist  │           │    │
│  │  │ (CRUD)   │ │ (Fwd/Bwd)│ │ (Toggle) │ │ (I/O)    │           │    │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ╔══════════════════════════════════════════════════════════════════════╗
│  ║                 SDK LAYER (Public API for Modules)                    ║
│  ║  SDK → Access │ AI Context │ Capability │ Dashboard │ Navigation   ║
│  ║  SDK → Notification │ Organization │ Policy │ Shell │ Spatial      ║
│  ║  SDK → Workflow │ Workspace │ API Guard │ Versioning               ║
│  ╚══════════════════════════════════════════════════════════════════════╝
│                                                                          │
│  ╔══════════════════════════════════════════════════════════════════════╗
│  ║              OBSERVABILITY / MONITORING                               ║
│  ║  RuntimeMetrics │ Watchdog │ TraceCollector │ EventObserver         ║
│  ║  EventJournal │ CheckpointStore │ PipelineInstrumentation           ║
│  ║  AuditLogSink │ ProviderHealthMonitor │ Diagnostics Overlay         ║
│  ╚══════════════════════════════════════════════════════════════════════╝
│                                                                          │
│  ╔══════════════════════════════════════════════════════════════════════╗
│  ║              FEATURE MODULES (Consumers of Runtime)                   ║
│  ║  18 feature modules consuming SDK + engines + shell                 ║
│  ║  Each provides: ModuleRuntimeDescriptor + WidgetBuilders             ║
│  ╚══════════════════════════════════════════════════════════════════════╝
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## PHASE 3 — DETECT DUPLICATES

### 3.1 Event Bus Duplication

| Candidate A | Candidate B | Overlap | Verdict |
|-------------|-------------|---------|---------|
| **AppEventBus** (`lib/core/events/app_event_bus.dart`) | **DashboardEventBus** (`lib/core/dashboard_engine/application/events/dashboard_event_bus.dart`) | Both are singleton broadcast StreamControllers for AppEvent subclasses | **OVERLAP** — DashboardEventBus may duplicate AppEventBus functionality |
| **AppEventBus** | **MappingSyncEventBus** | Both carry event notifications | **OVERLAP** — MappingSyncEventBus could use AppEventBus |

**Details**:
- `AppEventBus` is the system-wide bus handling: ModuleUpdatedEvent, ModuleInstalledEvent, DashboardPatchEvent, RuntimeSyncEvent, SystemBootEvent, SystemErrorEvent, WorkflowEvent
- `DashboardEventBus` is a separate bus in the dashboard engine with its own StreamController
- `MappingSyncEventBus` is another separate bus for mapping sync events
- These three buses fragment event routing instead of using a single typed event bus with filters

### 3.2 Composition Bridge Duplication

| Candidate A | Candidate B | Overlap | Verdict |
|-------------|-------------|---------|---------|
| **CapabilityCompositionBridge** | **PolicyCompositionBridge** | Both bridge engines to composition providers | **PARTIAL OVERLAP** — Similar pattern but different engines |
| **OrganizationRuntimeBridge** | **RuntimeDecisionBridge** | Both bridge governance to runtime | **PARTIAL OVERLAP** — Different concerns but similar wiring |
| **SpatialCompositionBridge** | **WorkspaceBridge** | Both bridge subsystems to composition | **PARTIAL OVERLAP** — Different domains but same pattern |

**Details**: Every subsystem defines its own `*Bridge` for composition integration: capability, policy, organization, spatial, runtime_decision, workspace. This is a deliberate hexagonal architecture choice, not accidental duplication. Each bridge adapts a specific domain to composition. However, they share identical plumbing patterns that could be abstracted.

### 3.3 Engine Duplication

| Candidate A | Candidate B | Overlap | Verdict |
|-------------|-------------|---------|---------|
| **DashboardCompositionEngine** | **DynamicCompositionEngine** | Both in `dashboard_engine/application/composition/` | **OVERLAP** — Two composition engines exist side by side |
| **DashboardRuntimeReconciler** | **ModuleRuntimeReconciler** | Both perform state reconciliation | **PARTIAL OVERLAP** — Dashboard vs Module runtime, but same reconciliation pattern |
| **RuntimePipelineOrchestrator** | **WorkflowOrchestrator** | Both orchestrate multi-step pipelines with stages | **PARTIAL OVERLAP** — Pipeline orchestrator handles dashboard events; WorkflowOrchestrator handles cross-module workflows. Same stage-based pattern. |

**Details**:
- `DashboardCompositionEngine` at `lib/core/dashboard_engine/application/composition/dashboard_composition_engine.dart`
- `DynamicCompositionEngine` at `lib/core/dashboard_engine/application/composition/dynamic_composition_engine.dart`
- These two files sit in the same directory with overlapping responsibilities. One likely supersedes the other.

### 3.4 Reconciler Duplication

| Candidate A | Candidate B | Overlap | Verdict |
|-------------|-------------|---------|---------|
| **DashboardRuntimeReconciler** | **ModuleRuntimeReconciler** | Both reconcile runtime state | **OVERLAP** — Same pattern, different scopes (dashboard patches vs module runtime state) |
| **DashboardConflictResolver** | **ConflictBuffer** | Both handle event conflicts | **OVERLAP** — ConflictResolver defines conflict strategies; ConflictBuffer uses