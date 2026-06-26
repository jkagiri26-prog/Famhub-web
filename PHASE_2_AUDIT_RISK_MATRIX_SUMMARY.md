# PHASE 2 AUDIT: QUICK REFERENCE - ACTIVE SOT & RISK MATRIX
**Audit Date**: May 28, 2026  
**Purpose**: Consolidated findings with actionable insights

---

## ACTIVE SOURCE OF TRUTH PER DOMAIN

### ✅ Confirmed by Real Usage Patterns

```
╔════════════════════════════════════════════════════════════════╗
║                    ACTIVE SOURCES OF TRUTH                    ║
║                     (Usage-Confirmed)                         ║
╠════════════════════════════════════════════════════════════════╣
║
║  DOMAIN: User Identity & Authentication
║  ┣━ Primary SOT: context.contextProvider
║  ┣━ Location: main.dart entry point (line 58)
║  ┣━ Pattern: .init() + .watch()
║  ┣━ Files: 4 (main.dart, app_shell, feature_gate, farm_context)
║  ┗━ Confidence: ✅ CONFIRMED (direct bootstrap)
║
║  DOMAIN: Active Role Management
║  ┣━ Primary SOT: context.contextProvider
║  ┣━ Location: unified_app_shell.dart, feature_gate_widget.dart
║  ┣━ Pattern: .watch(contextProvider)
║  ┣━ Files: 2
║  ┗━ Confidence: ✅ CONFIRMED (UI access control)
║
║  DOMAIN: Route Guard & Navigation Authorization
║  ┣━ Secondary SOT: context_engine.contextProvider
║  ┣━ Location: app_router2.dart, route_guards.dart
║  ┣━ Pattern: .read() in guards
║  ┣━ Files: 3 (routing layer only)
║  ┗━ Confidence: ✅ CONFIRMED (routing-isolated)
║
║  DOMAIN: Module Runtime State
║  ┣━ Primary SOT: moduleRuntimeSyncProvider
║  ┣━ Location: runtime_sync_engine.dart
║  ┣━ Pattern: .updateState() + realtime subscriptions
║  ┣━ Files: 2
║  ┗━ Confidence: ✅ CONFIRMED (Supabase-backed)
║
║  DOMAIN: Dashboard Composition & Rendering
║  ┣━ Primary SOT: dashboardCompositionEngineProvider + dashboardZoneRenderProvider
║  ┣━ Location: unified_dashboard_host.dart + runtime_sync_engine
║  ┣━ Pattern: .watch() + .read()
║  ┣━ Files: 3+
║  ┗━ Confidence: ✅ CONFIRMED (rendering pipeline)
║
║  DOMAIN: Dashboard Health & Monitoring
║  ┣━ Primary SOT: dashboardRuntimeWatchdogProvider
║  ┣━ Location: runtime_sync_engine + health snapshot provider
║  ┣━ Pattern: .read() + .watch()
║  ┣━ Files: 3
║  ┗━ Confidence: ✅ CONFIRMED (observability)
║
║  DOMAIN: System Telemetry & Tracing
║  ┣━ Primary SOT: traceCollectorProvider
║  ┣━ Location: runtime_sync_engine + execution_stage + executors
║  ┣━ Pattern: .read().log()
║  ┣━ Files: 3
║  ┗━ Confidence: ✅ CONFIRMED (logging)
║
╚════════════════════════════════════════════════════════════════╝
```

---

## DEAD/LEGACY MODULES

### Finding: ZERO

```
Searched: All 4 core modules
├─ core/context                  → 4 files using it ✅
├─ core/context_engine           → 3 files using it ✅
├─ core/module_runtime_sync      → 2 files using it ✅
└─ core/dashboard_engine         → 13+ files using it ✅

Result: 100% of modules have active consumers
Status: No dead code detected ✅
```

---

## MIXED USAGE RISKS (PRODUCTION ISSUES)

### 🔴 CRITICAL ISSUE #1: Dual Context Initialization

**Risk**: Context state could diverge

**Current Flow**:
```
main.dart (line 58)
  └─> context.contextProvider.init()      [PRIMARY INIT]
      └─> UI layer waits for initialization
      
SEPARATE:

app_router2.dart
  └─> context_engine.contextProvider      [SECONDARY, independent]
      └─> Router guarding uses this
```

**Problem**:
- Two separate context systems exist
- Init sequence unclear if both run
- Possible state inconsistency
- No explicit coordination

**Impact**: 
- 🔴 CRITICAL if both initialize separately
- 🟡 MAJOR if only one initializes but other is checked

**Recommendation**: 
Verify ONE of these is true:
1. context_engine derives from context (should it?)
2. Only one module initializes (which?)
3. They're intentionally separate systems (document why)

---

### 🔴 CRITICAL ISSUE #2: Persistence Contract Undefined

**Risk**: App state persistence unknown

**Evidence**:
- context.contextProvider is used in main.dart
- context_engine exists with storage services
- Unclear which owns persistence
- No contract document exists

**Problem**:
- If context initializes but doesn't persist, user logged out on restart
- If context_engine persists but isn't initialized, data stale
- Role/entity changes might not survive app restart

**Impact**: 
- 🔴 CRITICAL if not resolved

**Recommendation**: 
Explicitly document:
1. Which module owns persistence? (context or context_engine?)
2. When is persist called? (in .init()? async?)
3. What data is persisted? (userId? role? entityId?)

---

### 🟡 MAJOR ISSUE #3: Provider Name Collision

**Risk**: Import ambiguity in future refactoring

**Current State**:
```dart
// context module
final contextProvider = StateNotifierProvider<ContextNotifier, AppContext>

// context_engine module  
final contextProvider = StateNotifierProvider<ContextController, EntityContext>
```

**Problem**:
- Dart's name resolution prevents collision TODAY
- But any refactoring combining modules fails immediately
- Type system won't catch it until runtime
- Developer confusion when consolidating

**Impact**: 
- 🟡 MAJOR refactoring blocker
- 🔴 CRITICAL if both imported in same file

**Recommendation**: 
Rename one:
- Option A: `contextEngineProvider` in context_engine
- Option B: `uiContextProvider` in context
- Option C: Merge modules if they're meant to be one

---

### 🟡 MAJOR ISSUE #4: Bootstrap Order Undocumented

**Risk**: Initialization failures if order changes

**Current Sequence** (lines 15-48 in main.dart):
```dart
1. Supabase.initialize()
2. ProviderContainer()
3. DashboardBootstrap.initializeFromSystem()
4. RuntimeSyncEngine.initialize()
5. runApp()
   └─> Future.microtask(() => context.init())
```

**Problem**:
- No comments explaining why this order
- If step 4 needs user context (from step 5), fails
- New developers don't know order matters
- No error if order accidentally changes

**Impact**: 
- 🟡 MAJOR if fragile dependencies exist
- 🔴 CRITICAL if app crashes silently

**Recommendation**:
Document dependency graph:
```
Supabase → DashboardBootstrap → RuntimeSyncEngine → ContextInit
              (why this order?)
```

---

### 🟡 MAJOR ISSUE #5: Dashboard Engine Tight Coupling

**Risk**: Changes ripple through orchestration

**Evidence**:
runtime_sync_engine.dart imports 13+ dashboard_engine components:
```
dashboardRuntimePatchProvider
dashboardRuntimeWatchdogProvider
DashboardRuntimeReconciler
DashboardRuntimeDiff
SmartPatchCoalescer
RuntimePipelineOrchestrator
DashboardCompositionEngine
[8 more...]
```

**Problem**:
- Any dashboard_engine provider signature change breaks runtime_sync_engine
- No abstraction layer
- Direct dependency coupling
- Difficult to test in isolation

**Impact**: 
- 🟡 MAJOR maintenance burden
- Changes require coordination across modules

**Recommendation**:
Consider facade pattern:
```dart
// Instead of 13 direct imports:
ref.read(dashboardEngineProvider)
  .applyPatch(...)
  .startWatchdog(...)
  .log(...)
```

---

### 🟢 LOW RISK: Feature Derivation Pattern

**Finding**: farm_context_provider correctly derives from context

```dart
farm_context_provider.dart watches contextProvider
└─> Derives farm-specific context
└─> Correct layering
```

**Status**: ✅ No issues

---

## RISK MATRIX (CONSOLIDATED)

| Risk | Severity | Status | Impact | Owner |
|------|----------|--------|--------|-------|
| Dual context init | 🔴 CRITICAL | Not Resolved | State divergence | Architecture |
| Persistence undefined | 🔴 CRITICAL | Not Resolved | Data loss | Core team |
| Provider collision | 🟡 MAJOR | Prevented today | Refactoring blocker | Development |
| Bootstrap order | 🟡 MAJOR | Not Resolved | Fragile startup | Bootstrap owner |
| Dashboard coupling | 🟡 MAJOR | Accepted | Maintenance cost | Dashboard team |
| Feature derivation | 🟢 LOW | Working | None | N/A |

---

## CONSUMER USAGE DISTRIBUTION

```
CONTEXT MODULE (4 files - HIGH USAGE)
├─ lib/main.dart                          [ENTRY POINT - PRIMARY]
├─ lib/core/shell/unified_app_shell.dart  [SHELL LAYER]
├─ lib/shared/widgets/gates/feature_gate_widget.dart  [ACCESS CONTROL]
└─ lib/features/farm_management/application/providers/farm_context_provider.dart  [DERIVED]

CONTEXT_ENGINE MODULE (3 files - MEDIUM USAGE)
├─ lib/core/router/app_router2.dart      [ROUTER - PRIMARY]
├─ lib/core/router/route_guards.dart     [GUARDS]
└─ lib/core/router/route_notifier.dart   [LISTENER]

MODULE_RUNTIME_SYNC (2 files - MEDIUM USAGE)
├─ lib/main.dart                          [ENTRY POINT]
└─ lib/core/module_runtime_sync/runtime_sync_engine.dart  [CORE]

DASHBOARD_ENGINE (13+ files - HIGH USAGE)
├─ lib/main.dart                          [BOOTSTRAP]
├─ lib/core/shell/unified_dashboard_host.dart  [RENDERING]
├─ lib/core/module_runtime_sync/runtime_sync_engine.dart  [ORCHESTRATION HUB]
├─ [10+ supporting/internal files]
└─ Status: DISTRIBUTED across pipeline
```

---

## RECOMMENDATIONS BY PHASE

### IMMEDIATE (This Sprint)

1. **Document Persistence Contract**
   - Which module owns persistence?
   - When is data persisted?
   - What survives app restart?
   - Estimated effort: 4 hours (documentation)

2. **Document Bootstrap Dependency Graph**
   - Why is initialization order this way?
   - What breaks if order changes?
   - Add comments to main.dart
   - Estimated effort: 2 hours (documentation)

3. **Verify Dual Context Behavior**
   - Does context_engine.init() get called?
   - If so, WHEN relative to context.init()?
   - Are they intentionally separate?
   - Estimated effort: 4 hours (investigation)

### SHORT-TERM (Next Sprint)

4. **Resolve Provider Naming Collision**
   - Rename context_engine.contextProvider → contextEngineProvider
   - Update all 3 files (route_notifier, route_guards, app_router2)
   - Estimated effort: 2 hours (refactoring)

5. **Consider Context System Unification**
   - Do we need both context and context_engine?
   - If yes, explicitly separate concerns (UI vs routing)
   - If no, consolidate into single module
   - Estimated effort: 16-40 hours (design + refactoring)

### MEDIUM-TERM (Next Quarter)

6. **Decouple Dashboard Engine from Runtime Sync**
   - Create facade/interface layer
   - Reduce 13 direct imports to 2-3
   - Estimated effort: 24-40 hours (refactoring)

---

## VALIDATION CHECKLIST

Use this to verify Phase 2 findings:

- [ ] Run app and verify context initialization completes
- [ ] Check local storage after app restart (is user still logged in?)
- [ ] Verify route guards work correctly (test authRequired route)
- [ ] Check dashboard loads after module state changes
- [ ] Verify feature gates work (role-based access)
- [ ] Monitor app startup logs (all 5 bootstrap steps succeed?)
- [ ] Verify no state inconsistencies between context layers

---

## CONCLUSION

**All 4 core modules are ACTIVE in production.** No dead code detected.

**However**: Dual context systems and undefined contracts create CRITICAL risks that must be addressed before scaling.

**Recommended Action**: Resolve Issues #1 and #2 (dual context init, persistence contract) before adding new context-dependent features.
