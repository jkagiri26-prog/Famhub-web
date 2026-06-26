# PHASE 2 AUDIT: CONSUMER FLOW & REAL USAGE AUDIT
**Audit Date**: May 28, 2026  
**Analysis Type**: Static code analysis of actual imports and runtime usage patterns  
**Scope**: Trace all consumer files importing from the four core modules

---

## EXECUTIVE SUMMARY

✓ **Finding**: Both `context` AND `context_engine` are actively used in production  
✓ **Finding**: No dead/legacy modules detected  
⚠️ **Finding**: DUAL context systems integrated but in DIFFERENT application layers  
🔴 **Finding**: No unified context entry point; CRITICAL integration risk  

---

## PART 1: ENTRY POINT ANALYSIS

### Entry Point 1: **lib/main.dart**

```dart
// IMPORTS
import 'core/context/context_provider.dart';                    // ← context module
import 'core/dashboard_engine/bootstrap/dashboard_bootstrap.dart';
import 'core/module_runtime_sync/runtime_sync_engine.dart';
import 'core/module_runtime_sync/presentation/providers/module_runtime_sync_provider.dart';

// BOOTSTRAP SEQUENCE (Lines 15-48)
void main() async {
  // 1️⃣ Supabase initialization
  await Supabase.initialize(...)
  
  // 2️⃣ Root provider container
  final container = ProviderContainer();
  
  // 3️⃣ Dashboard bootstrap (calls: DashboardBootstrap.initializeFromSystem())
  await DashboardBootstrap.initializeFromSystem();
  
  // 4️⃣ Module runtime sync engine
  final runtimeSyncEngine = RuntimeSyncEngine(...);
  await runtimeSyncEngine.initialize();
  
  // 5️⃣ App launch
  runApp(UncontrolledProviderScope(...));
}

// WIDGET INIT (Lines 59-61)
class _MyAppState extends ConsumerState<MyApp> {
  void initState() {
    Future.microtask(() async {
      await ref.read(contextProvider.notifier).init();  // ← context.init() called
    });
  }
  
  // USAGE (Line 65)
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);  // ← Watches context for isLoading
    
    if (ctx.isLoading) {
      return LoadingScreen();
    }
    // ...
  }
}
```

**Entry Point Analysis**:
- ✅ Uses `context.contextProvider` (NOT context_engine)
- ✅ Calls `contextProvider.notifier.init()` 
- ⚠️ Assumption: `context` module handles initialization
- ⚠️ NO direct usage of `contextProvider` from context_engine at root level

**Critical Gap**: Main.dart uses `context` for init but `context_engine` contains actual persistence logic!

---

### Entry Point 2: **lib/core/shell/unified_app_shell.dart**

```dart
// IMPORT
import '../context/context_provider.dart';  // ← context module

// USAGE
class AppShell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);  // ← Watches context
    
    if (ctx.isSystemDown) {
      return Scaffold(...);
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Device-aware shell selection
        if (constraints.maxWidth < 600) {
          return MobileShell(...);
        } else if (constraints.maxWidth < 1024) {
          return TabletShell(...);
        } else {
          return DesktopShell(...);
        }
      },
    );
  }
}
```

**Entry Point Analysis**:
- ✅ Uses `context.contextProvider` 
- ✅ Accesses `isSystemDown` flag
- ✅ UI-layer structural gate (not routing)
- ⚠️ No integration with context_engine

---

### Entry Point 3: **lib/core/shell/unified_dashboard_host.dart**

```dart
// IMPORTS
import '../dashboard/application/providers/dashboard_provider.dart';
import '../dashboard_engine/application/composition/dashboard_composition_engine.dart';
import '../dashboard_engine/application/providers/dashboard_zone_render_provider.dart';

// USAGE
class UnifiedDashboardHost extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1️⃣ Watch module state
    final asyncModules = ref.watch(dashboardProvider(moduleKey));
    
    // 2️⃣ Watch zone render state
    final zoneState = ref.watch(dashboardZoneRenderProvider);
    
    return asyncModules.when(
      data: (modules) {
        // 3️⃣ Retrieve composition engine
        final compositionEngine = ref.read(dashboardCompositionEngineProvider);
        final renderer = ref.read(dashboardRendererProvider(moduleKey));
        
        // 4️⃣ Build composition
        return FutureBuilder(
          future: compositionEngine.build(
            context: _buildContext(context),
            modules: modules,
          ),
          builder: (context, snapshot) {
            // 5️⃣ Render via dashboard renderer
            return renderer.render(snapshot: composed, zoneState: zoneState);
          },
        );
      },
    );
  }
}
```

**Entry Point Analysis**:
- ✅ Uses `dashboard_engine` exclusively
- ✅ NO context or context_engine imports
- ✅ Composition-driven rendering
- ✓ Clean separation from context layer

---

## PART 2: CONSUMER MAP (ALL IMPORTS)

### A. **context.contextProvider IMPORTS** (4 files)

#### 1️⃣ **lib/main.dart** (PRIMARY ENTRY POINT)
```dart
import 'core/context/context_provider.dart';

Usage:
  Line 58: ref.read(contextProvider.notifier).init()      [CRITICAL PATH]
  Line 65: ref.watch(contextProvider)                     [UI gate]
  Purpose: Root application initialization + loading state gate
  Pattern: ACTIVE ✅
```

#### 2️⃣ **lib/core/shell/unified_app_shell.dart** (SHELL LAYER)
```dart
import '../context/context_provider.dart';

Usage:
  Line 16: ref.watch(contextProvider)                     [UI state]
  Purpose: System state gate (isSystemDown check)
  Pattern: ACTIVE ✅
```

#### 3️⃣ **lib/shared/widgets/gates/feature_gate_widget.dart** (FEATURE GATES)
```dart
import '../../core/context/context_provider.dart';

Usage:
  ref.watch(contextProvider)                              [Access control]
  Purpose: Feature gating based on role.activeRole
  Pattern: ACTIVE ✅
```

#### 4️⃣ **lib/features/farm_management/application/providers/farm_context_provider.dart** (DERIVED STATE)
```dart
import '../../../core/context/context_provider.dart';

Usage:
  ref.watch(contextProvider)                              [Dependency]
  Purpose: Derive farm-specific context from global context
  Pattern: ACTIVE ✅
```

**Summary**:
- Total: 4 files
- All ACTIVE ✅
- Primary usage: UI gates, feature access control, derived state
- Entry point control: main.dart

---

### B. **context_engine.contextProvider IMPORTS** (3 files)

#### 1️⃣ **lib/core/router/app_router2.dart** (ROUTER CORE)
```dart
import '../context_engine/context_provider.dart';

Usage:
  ref.read(contextProvider)                               [Router state]
  Purpose: Validate guest/auth status in route redirects
  Pattern: ACTIVE ✅
```

#### 2️⃣ **lib/core/router/route_guards.dart** (ROUTE GUARDS)
```dart
import '../context_engine/context_provider.dart';

Usage:
  ref.read(contextProvider)                               [Guard validation]
  Purpose: 4 guard functions use EntityContext:
    - guestOnly()
    - authRequired()
    - roleRequired(role)
    - entityRequired()
  Pattern: ACTIVE ✅
```

#### 3️⃣ **lib/core/router/route_notifier.dart** (ROUTE LISTENER)
```dart
import '../context_engine/context_provider.dart';

Usage:
  ref.listen(contextProvider, (_, __) => notifyListeners())  [Side effect]
  Purpose: Trigger route invalidation on context changes
  Pattern: ACTIVE ✅
```

**Summary**:
- Total: 3 files
- All ACTIVE ✅
- Primary usage: Route guarding, navigation control
- Entry point control: app_router2.dart

---

### C. **module_runtime_sync_provider IMPORTS** (2 files)

#### 1️⃣ **lib/main.dart** (IMPORT + INDIRECT USE)
```dart
import 'core/module_runtime_sync/presentation/providers/module_runtime_sync_provider.dart';

Usage:
  Imported but not directly called in main.dart
  Passed to RuntimeSyncEngine coordinator
  Pattern: ACTIVE ✅
```

#### 2️⃣ **lib/core/module_runtime_sync/runtime_sync_engine.dart** (CORE ENGINE)
```dart
import 'package:famhub_app/core/module_runtime_sync/presentation/providers/module_runtime_sync_provider.dart';

Usage:
  ref.read(moduleRuntimeSyncProvider)
  ref.read(moduleRuntimeSyncProvider.notifier).updateState()
  Purpose: State lifecycle management
  Pattern: ACTIVE ✅
```

**Summary**:
- Total: 2 files
- All ACTIVE ✅
- Centralized in RuntimeSyncEngine
- Not used in UI layer directly

---

### D. **dashboard_engine IMPORTS** (13+ files)

#### **Core Files (High Usage)**

1️⃣ **lib/core/shell/unified_dashboard_host.dart**
```dart
Usage:
  dashboardCompositionEngineProvider (.read)
  dashboardZoneRenderProvider (.watch)
  dashboardRendererProvider (.read)
  Pattern: ACTIVE ✅
```

2️⃣ **lib/core/module_runtime_sync/runtime_sync_engine.dart** (CRITICAL)
```dart
Usage:
  13+ dashboard_engine imports:
    - dashboardRuntimePatchProvider (.notifier.applyPatch)
    - dashboardRuntimeWatchdogProvider (.read/.watch)
    - traceCollectorProvider (.read) [3 usages]
    - DashboardCompositionEngine
    - DashboardRuntimeReconciler
    - DashboardRuntimeDiff
    - SmartPatchCoalescer
    - RuntimePipelineOrchestrator
    - [and 5+ more]
  Purpose: Pipeline orchestration + health monitoring
  Pattern: ACTIVE ✅ [CENTRAL HUB]
```

3️⃣ **lib/main.dart**
```dart
Usage:
  DashboardBootstrap.initializeFromSystem()
  Pattern: ACTIVE ✅ [STARTUP]
```

#### **Supporting Files (Medium Usage)**

4️⃣ **lib/core/dashboard_engine/application/executor/dashboard_patch_executor.dart**
```dart
Usage:
  dashboardZoneRenderProvider (.notifier)
  Pattern: ACTIVE ✅
```

5️⃣ **lib/core/dashboard_engine/application/executor/safe_dashboard_patch_executor.dart**
```dart
Usage:
  traceCollectorProvider (.read)
  Pattern: ACTIVE ✅
```

6️⃣ **lib/core/dashboard_engine/application/pipeline/stages/execution_stage.dart**
```dart
Usage:
  traceCollectorProvider (.read) [2 usages]
  Pattern: ACTIVE ✅
```

7️⃣ **lib/core/dashboard_engine/application/providers/dashboard_health_snapshot_provider.dart**
```dart
Usage:
  dashboardRuntimeWatchdogProvider (.watch)
  Pattern: ACTIVE ✅
```

#### **System Integration**

8️⃣ **lib/system/modules_control/module_loader.dart**
```dart
Usage:
  dashboard_engine/infrastructure/adapters/module_runtime_adapter
  Pattern: ACTIVE ✅
```

#### **Internal (Definition)**

9️⃣ **lib/core/dashboard_engine/bootstrap/dashboard_bootstrap.dart**
```dart
Usage: Internal module bootstrap
Pattern: CORE 📌
```

**Summary**:
- Total: 13+ files
- All ACTIVE ✅
- Primary hub: `runtime_sync_engine.dart` (13 imports)
- Secondary hub: `unified_dashboard_host.dart` (3 imports)
- Startup: `main.dart` (1 import)
- Not used in UI feature layer

---

## PART 3: USAGE FREQUENCY SCORE

### Scoring Methodology
- **HIGH**: Used in 4+ files OR in critical path (main.dart, entry points, orchestrators)
- **MEDIUM**: Used in 2-3 files OR in secondary systems
- **UNUSED**: Not imported by any production file

### Results

| Module/Provider | Files | Critical Path | Scoring | Rating |
|---|---|---|---|---|
| **context.contextProvider** | 4 | main.dart, app_shell | 4 files + entry point | 🔴 **HIGH** |
| **context_engine.contextProvider** | 3 | app_router2.dart (routing) | 3 files + router logic | 🟡 **MEDIUM** |
| **moduleRuntimeSyncProvider** | 2 | runtime_sync_engine | 2 files + core orchestrator | 🟡 **MEDIUM** |
| **dashboardCompositionEngineProvider** | 3 | unified_dashboard_host | 3+ files + rendering | 🔴 **HIGH** |
| **dashboardZoneRenderProvider** | 3 | unified_dashboard_host + patch executor | 3+ files + zone rendering | 🔴 **HIGH** |
| **dashboardRuntimePatchProvider** | 1 | runtime_sync_engine | 1 file + core orchestrator | 🟡 **MEDIUM** |
| **dashboardRuntimeWatchdogProvider** | 3 | runtime_sync_engine + health | 3+ files + monitoring | 🔴 **HIGH** |
| **traceCollectorProvider** | 3 | runtime_sync_engine + telemetry | 3+ files + observability | 🟡 **MEDIUM** |

### Usage Frequency Distribution

```
HIGH USAGE (Core App Flow)
  ✓ context.contextProvider              [4 files, UI layer entry]
  ✓ dashboardCompositionEngineProvider   [3 files, rendering]
  ✓ dashboardZoneRenderProvider          [3 files, zone state]
  ✓ dashboardRuntimeWatchdogProvider     [3 files, health]

MEDIUM USAGE (Secondary Systems)
  ✓ context_engine.contextProvider       [3 files, routing layer]
  ✓ moduleRuntimeSyncProvider            [2 files, sync engine]
  ✓ dashboardRuntimePatchProvider        [1 file, centralized]
  ✓ traceCollectorProvider               [3 files, telemetry]

UNUSED / LEGACY
  ✗ NONE DETECTED
```

---

## PART 4: RISK CONFIRMATION

### Risk 1: Is context module still active or legacy?

**Answer**: ✅ **CONTEXT IS ACTIVE & PRIMARY** (NOT legacy)

**Evidence**:
- Used in main.dart entry point
- Handles critical `.init()` call
- Accessed by 4 active files
- Used in primary UI gate (app shell, feature gates)
- **Location**: UI/Widget layer

**Risk Level**: 🟢 LOW (clear usage)

---

### Risk 2: Is context_engine fully adopted or partial?

**Answer**: ⚠️ **CONTEXT_ENGINE IS ACTIVE BUT PARTIAL** (used in routing only)

**Evidence**:
- Used in 3 files (ALL routing/navigation)
- NOT used in main.dart entry point
- NOT used in UI widget layer
- Isolated to router module
- **Location**: Routing/Navigation layer only

**Risk Level**: 🟡 MEDIUM (limited scope)

---

### Risk 3: Are both being used in production paths?

**Answer**: 🔴 **YES - BOTH USED IN PRODUCTION PATHS**

**Evidence**:
```
PRODUCTION PATH 1 (UI/Widget Layer):
  main.dart
    → context.contextProvider.init()      [PRIMARY]
    → ref.watch(contextProvider)
    → unified_app_shell.dart
      → ref.watch(contextProvider)
    → feature_gate_widget.dart
      → ref.watch(contextProvider)

PRODUCTION PATH 2 (Routing/Navigation Layer):
  app_router2.dart
    → context_engine.contextProvider
    → route_guards.dart
      → context_engine.contextProvider    [SECONDARY]
    → route_notifier.dart
      → context_engine.contextProvider

RESULT: Dual context systems in DIFFERENT application layers
```

**Risk Level**: 🔴 CRITICAL (dual systems, potential state divergence)

---

### Risk 4: Module Runtime Sync - Active?

**Answer**: ✅ **YES - ACTIVE IN CORE ORCHESTRATION**

**Evidence**:
- Imported in main.dart
- RuntimeSyncEngine is central hub for dashboard engine
- Manages module state lifecycle
- Triggers reconciliation pipeline
- Integrated with 13+ dashboard_engine components

**Risk Level**: 🟢 LOW (clear orchestration role)

---

### Risk 5: Dashboard Engine - Active?

**Answer**: ✅ **YES - ACTIVE IN RENDERING & STATE MANAGEMENT**

**Evidence**:
- 13+ files actively import dashboard_engine providers
- Central to composition pipeline
- Health monitoring via watchdog
- Zone rendering state
- Integrated with module_runtime_sync

**Risk Level**: 🟢 LOW (core rendering system)

---

## PART 5: ACTIVE SOURCE OF TRUTH (CONFIRMED BY USAGE)

### **Confirmed SOT Per Domain** (Updated from Phase 1)

| Domain | Theoretical SOT (Phase 1) | **CONFIRMED SOT (Phase 2 - Usage-Based)** | Status |
|---|---|---|---|
| **User Identity** | context_engine (ambiguous) | `context.contextProvider` | ✅ CONFIRMED PRIMARY |
| **Active Role** | context_engine (ambiguous) | `context.contextProvider` | ✅ CONFIRMED PRIMARY |
| **Context Initialization** | Unknown | `context.contextProvider.init()` | ✅ CONFIRMED ACTIVE |
| **Route Guarding** | Unknown | `context_engine.contextProvider` | ✅ CONFIRMED SECONDARY |
| **Module State** | module_runtime_sync | `moduleRuntimeSyncProvider` | ✅ CONFIRMED |
| **Dashboard Composition** | dashboard_engine | `dashboardCompositionEngineProvider` | ✅ CONFIRMED |
| **Zone Rendering** | dashboard_engine | `dashboardZoneRenderProvider` | ✅ CONFIRMED |
| **Health Monitoring** | dashboard_engine | `dashboardRuntimeWatchdogProvider` | ✅ CONFIRMED |

**Key Finding**: Phase 1 had theoretical ambiguity about user context. Phase 2 reveals:
- **`context` is PRIMARY** in UI/widget layer (main.dart controls init)
- **`context_engine` is SECONDARY** in routing layer (isolated to guards)

---

## PART 6: DEAD/LEGACY MODULES

### Finding: **ZERO DEAD MODULES**

**Analysis**:
- Scanned all 4 core modules
- All had active imports
- All had observable usage patterns (.watch, .read, .listen, .notifier)
- No orphaned code detected
- No unused providers in system

**Conclusion**: ✓ All four modules are active in production.

---

## PART 7: MIXED USAGE RISKS (CRITICAL FINDINGS)

### 🔴 CRITICAL RISK 1: Dual Context Systems

**Problem**:
```
main.dart
  ↓
  context.contextProvider.init()     [PRIMARY]
  ↓
  App state initialized via: context module
  
  BUT
  
app_router2.dart
  ↓
  context_engine.contextProvider     [SECONDARY]
  ↓
  Route state initialized via: context_engine module
  
  PROBLEM: Two separate inits, two separate state models
```

**Impact**:
- Main.dart initializes `context` context
- Router initializes `context_engine` context independently
- If both try to load/sync user data, could cause:
  - State divergence
  - Lost updates
  - Inconsistent role information
  - Silent failures

**Current State**: UNKNOWN if both initialize or only one

**Risk Severity**: 🔴 CRITICAL

---

### 🔴 CRITICAL RISK 2: Context Provider Collision

**Problem**:
```dart
// Two providers with same name, different modules:

import 'core/context/context_provider.dart';         // Module A
import 'core/context_engine/providers/context_provider.dart';  // Module B

// In same file:
final ctx1 = ref.watch(contextProvider);     // Which one??
```

**Current State**: Actively prevented by Dart's naming conflict detection

**But Problem Remains**: Any developer refactoring or consolidating these files would immediately hit collision

**Risk Severity**: 🔴 CRITICAL (future refactoring blocker)

---

### 🟡 MAJOR RISK 3: Hidden Orchestration Coupling

**Problem**:
```
runtime_sync_engine.dart imports 13+ dashboard_engine providers:
  ├─ dashboardRuntimePatchProvider
  ├─ dashboardRuntimeWatchdogProvider
  ├─ DashboardRuntimeReconciler
  ├─ DashboardRuntimeDiff
  ├─ SmartPatchCoalescer
  ├─ RuntimePipelineOrchestrator
  └─ [8 more...]
```

**Issue**: 
- If any dashboard_engine provider changes signature, runtime_sync_engine breaks
- No abstraction layer to decouple
- Changes propagate directly

**Current State**: Works but fragile

**Risk Severity**: 🟡 MAJOR (tight coupling)

---

### 🟡 MAJOR RISK 4: Bootstrap Order Not Documented

**Problem**:
```
Initialization sequence:
  1. Supabase.initialize()
  2. DashboardBootstrap.initializeFromSystem()
  3. RuntimeSyncEngine.initialize()
  4. main.dart → context.contextProvider.init()  [Future.microtask]

Question: What if step 3 needs context from step 4?
```

**Current State**: Order appears to work but undocumented dependencies

**Risk Severity**: 🟡 MAJOR (initialization fragility)

---

### 🟢 LOW RISK 5: Feature Derivation

**Finding**: 
- farm_context_provider derives from context
- This is correct pattern (derived state)
- No risk detected

**Risk Severity**: 🟢 LOW

---

## PART 8: CONSUMER FLOW DIAGRAM

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         APPLICATION STARTUP                              │
├──────────────────────────────────────────────────────────────────────────┤
│
│  void main() async {
│    1. Supabase.initialize()
│    2. ProviderContainer()
│    3. DashboardBootstrap.initializeFromSystem()
│    4. RuntimeSyncEngine.initialize()
│    5. runApp(MyApp)
│  }
│
└──────────────────────────────────────────────────────────────────────────┘
                                   ↓
                                   
                    ┌─────────────────────────────┐
                    │   MyApp._MyAppState         │
                    │   initState() {             │
                    │     context.init()  [ASYNC] │  ← Future.microtask
                    │   }                         │
                    └─────────────────────────────┘
                                   ↓
                ┌──────────────────────────────────────┐
                │                                      │
        [UI LAYER]                          [ROUTING LAYER]
                │                                      │
    ┌───────────┴──────────────┐          ┌───────────┴──────────────┐
    │                          │          │                          │
    v                          v          v                          v
context.              context.         context_engine.         context_engine.
contextProvider       contextProvider  contextProvider         contextProvider
(via init())          (watch/read)      (via route guards)      (listen)
    │                     │                    │                    │
    ├─> unified_      ├─> feature_gate   ├─> app_router2   └─> route_notifier
    │   app_shell      │   widget         │   (redirects)       (invalidates)
    │   (isLoaded)     │                  │
    │                  │                  └─> route_guards
    │                  │                     (guestOnly,
    │                  ├─> farm_context_     authRequired,
    │                  │   provider           roleRequired)
    │                  │   (derives farm
    │                  │    context)
    │                  │
    └─> Dashboard     └─> [UI Widgets]
        Host          
            │
            v
    ┌────────────────────────────┐
    │  dashboard_engine           │
    │  ├─ composition            │
    │  ├─ zone_render_state      │
    │  └─ watchdog/health        │
    │                            │
    │  Triggers:                 │
    │  ├─ reconciliation         │
    │  ├─ diff_generation        │
    │  ├─ patch_application      │
    │  └─ telemetry_logging      │
    └────────────────────────────┘
            ↑
            │
            └─ module_runtime_sync
               (watches module_state)
                     ↑
                     │
                Supabase
                 realtime
```

---

## PART 9: PRODUCTION BLOCKERS UPDATED (FROM PHASE 1 → PHASE 2)

| Blocker | Phase 1 Status | Phase 2 Finding | Updated Risk |
|---------|---|---|---|
| Context duplication | Ambiguous SOT | **CONFIRMED DUAL USE** | 🔴 CRITICAL |
| contextProvider collision | Theoretical | **ACTIVELY PREVENTED** by naming | 🟡 MAJOR |
| Persistence contract | Unknown | **context used, but HOW?** | 🔴 CRITICAL |
| Bootstrap order | Unknown | **Sequence exists but undocumented** | 🟡 MAJOR |
| Feature flag source | Unknown | **Still unclear** | 🟡 MAJOR |
| Module lifecycle | Unknown | **Working, tight coupling detected** | 🟡 MAJOR |

---

## PART 10: KEY CONSUMER INSIGHTS

### Consumer Pattern Analysis

| Pattern | Files | Risk | Recommendation |
|---------|-------|------|---|
| `.watch(contextProvider)` for UI gates | 4 | LOW | Keep as is (reactive) |
| `.read(contextProvider.notifier).init()` | 1 | HIGH | Document contract explicitly |
| `.read(context_engine) in guards` | 3 | MEDIUM | Ensure sync with UI context |
| `.read(dashboardXxxProvider)` | 8+ | MEDIUM | Consider facade pattern |
| `.listen(contextProvider)` | 1 | MEDIUM | Document side effects |

---

## SUMMARY TABLE

| Metric | Finding | Status |
|--------|---------|--------|
| **Total Active Modules** | 4 / 4 | ✅ All active |
| **Dead/Legacy Modules** | 0 | ✅ None |
| **Files Using context** | 4 | ✅ Active |
| **Files Using context_engine** | 3 | ✅ Active (routing only) |
| **Files Using module_runtime_sync** | 2 | ✅ Active (orchestration) |
| **Files Using dashboard_engine** | 13+ | ✅ Active (rendering) |
| **Provider Collisions Detected** | 1 (contextProvider) | 🔴 CRITICAL |
| **Dual Context Systems in Production** | 2 | 🔴 CRITICAL |
| **Critical Path Clear** | Mostly | 🟡 MAJOR gaps |
| **Bootstrap Order Documented** | No | 🔴 CRITICAL |
| **Confirmed Dead Code** | None | ✅ Zero |
