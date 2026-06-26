# PHASE 1 AUDIT: DUPLICATION MAP
**Audit Date**: May 28, 2026  
**Modules Audited**: core/module_runtime_sync, core/dashboard_engine, core/context, core/context_engine

---

## DUPLICATE ARTIFACTS IDENTIFIED

### **CRITICAL DUPLICATIONS**

#### 1. **User Context Management**
| Artifact | Module A | Module B | Severity |
|----------|----------|----------|----------|
| Context State Model | `context.AppContext` | `context_engine.EntityContext` | 🔴 CRITICAL |
| User Identity | `context.UserContext` | `context_engine.EntityContext.userId` | 🔴 CRITICAL |
| Role State | `context.RoleContext` | `context_engine.EntityContext.role` | 🔴 CRITICAL |
| State Notifier Class | `context.ContextNotifier` | `context_engine.ContextNotifier` | 🔴 CRITICAL |
| Riverpod Provider | `context.contextProvider` | `context_engine.contextProvider` | 🔴 CRITICAL |

**Impact**:
- Both modules define `contextProvider` with potentially conflicting names
- Both define `ContextNotifier` class (different implementations)
- Consumers importing from `context` vs `context_engine` get different state management strategies
- No clear guidance on which to use
- Risk of state inconsistency if both are used in same app

**Current State**:
```dart
// context/context_provider.dart
final contextProvider = StateNotifierProvider<ContextNotifier, AppContext>(...)

// context_engine/providers/context_provider.dart
final contextProvider = StateNotifierProvider<ContextController, EntityContext>(...)
```

**Problem**: Module name collision + semantic collision

---

#### 2. **Reconciliation Pattern**
| Artifact | Module A | Module B | Severity |
|----------|----------|----------|----------|
| Reconciler Class | `ModuleRuntimeReconciler` | `DashboardRuntimeReconciler` | 🟡 MAJOR |
| Reconciliation Logic | State machine pattern (module state) | State machine pattern (dashboard state) | 🟡 MAJOR |
| Diff Generation | `module_runtime_sync` internal | `DashboardRuntimeDiff` | 🟡 MAJOR |
| Conflict Resolution | `SmartPatchCoalescer` (module scope) | Patch executor (dashboard scope) | 🟡 MAJOR |

**Impact**:
- Similar reconciliation logic implemented twice
- Both use state machine patterns but domain-specific
- Code duplication risk for maintenance
- Pattern inconsistency if one is updated and not the other

**Current State**:
```dart
// module_runtime_sync/domain/models/reconciliation/
ModuleRuntimeReconciler {
  reconcile(currentState, event) → ModuleRuntimeState
}

// dashboard_engine/application/reconciliation/
DashboardRuntimeReconciler {
  reconcile(snapshot, moduleChanges) → List<DashboardRuntimeDiff>
}
```

**Problem**: Both implement similar patterns for different domains; no shared abstraction

---

### **MODERATE DUPLICATIONS**

#### 3. **State Mutation/Update Methods**
| Pattern | context | context_engine |
|---------|---------|---|
| Set user | `ContextNotifier.setUser(userId, entityId)` | `ContextController.switchEntity(entityId)` + `init()` |
| Set role | `ContextNotifier.setRole(role)` | `ContextController.switchRole(role)` |
| Reset state | `ContextNotifier.reset()` | `ContextController.logout()` |
| Loading state | `ContextNotifier.setLoading(bool)` | `ContextController.init()` (implicit) |

**Severity**: 🟡 MAJOR (different APIs, same intent)

**Impact**:
- Consumers use different APIs for similar operations
- No consistent pattern across app for context updates
- Migration path unclear if switching from `context` to `context_engine`

---

#### 4. **Pipeline Orchestration**
| Component | module_runtime_sync | dashboard_engine |
|-----------|---|---|
| Orchestrator | `RuntimeSyncEngine` | `RuntimePipelineOrchestrator` |
| Stage execution | Event → reconcile → diff → patch → execute | Reconcile → diff → patch → execute |
| Stage models | Implicit (internal) | Explicit `RuntimePipelineStage` abstraction |
| Provider management | `moduleRuntimeSyncProvider` | 13 providers (composition, reconciliation, patch, etc.) |

**Severity**: 🟡 MAJOR (similar concept, different architecture)

**Impact**:
- Two different orchestration patterns in same codebase
- `dashboard_engine` has explicit stage abstraction; `module_runtime_sync` implicit
- Unclear if they can interoperate or must remain separate
- Testing and debugging requires understanding both patterns

---

### **MINOR DUPLICATIONS**

#### 5. **Storage/Sync Service Patterns**
| Pattern | Where | Severity |
|---------|-------|----------|
| Local storage integration | `context_engine.ContextStorageService` | Unique to context_engine | 🟢 LOW |
| Backend sync | `context_engine.ContextSyncService` | Unique to context_engine | 🟢 LOW |
| Event subscription | `module_runtime_sync` (Supabase) | Unique to module_runtime_sync | 🟢 LOW |
| Patch execution | `dashboard_engine.SafeDashboardPatchExecutor` | Unique to dashboard_engine | 🟢 LOW |

**Impact**: LOW — these are domain-specific implementations

---

#### 6. **Bootstrap Logic**
| Module | Bootstrap Pattern | Severity |
|--------|---|---|
| `context_engine` | Load local → apply → sync → persist | 🟡 MAJOR |
| `dashboard_engine` | Initialize widget registry from modules | 🟡 MAJOR |
| `module_runtime_sync` | Initialize realtime subscription | 🟡 MAJOR |

**Severity**: 🟡 MAJOR (interdependencies unclear)

**Impact**:
- Three modules have independent bootstrap flows
- Unclear execution order dependencies
- If one fails, unclear impact on others
- No unified bootstrap coordinator visible

---

## DUPLICATION SEVERITY HEATMAP

```
CRITICAL    🔴 🔴 🔴
            ├─ context vs context_engine (user state models)
            ├─ contextProvider naming collision
            └─ ContextNotifier class duplication

MAJOR       🟡 🟡
            ├─ Reconciliation pattern (module vs dashboard)
            ├─ Pipeline orchestration architecture
            ├─ State mutation API inconsistency
            └─ Bootstrap coordination gaps

MINOR       🟢
            ├─ Service patterns (storage, sync)
            └─ Domain-specific implementations
```

---

## DUPLICATION IMPACT MATRIX

| Duplication | Causes State Inconsistency | Causes Maintenance Burden | Causes Runtime Error | Blocks Refactoring |
|---|:-:|:-:|:-:|:-:|
| User context models | ✓ | ✓ | ✓ | ✓ |
| contextProvider collision | ✓ | ✓ | ✓ | ✓ |
| Reconciliation patterns | | ✓ | | ✓ |
| Pipeline orchestration | | ✓ | | ✓ |
| State mutation APIs | | ✓ | | ✓ |
| Bootstrap interdependencies | | | ✓ | ✓ |

---

## AFFECTED FILES (DUPLICATES)

### **User Context Duplication**
```
context/
├── app_context.dart          ← AppContext model
├── user_context.dart         ← UserContext (userId, entityId)
├── role_context.dart         ← RoleContext (activeRole)
└── context_provider.dart     ← contextProvider

context_engine/
├── models/entity_context.dart          ← EntityContext model (userId, role, entityId)
├── controllers/context_notifier.dart   ← ContextNotifier (duplicate name)
├── controllers/context_controller.dart ← ContextController (advanced)
└── providers/context_provider.dart     ← contextProvider (COLLISION!)
```

### **Reconciliation Duplication**
```
module_runtime_sync/
└── application/reconciliation/
    └── module_runtime_reconciler.dart

dashboard_engine/
└── application/reconciliation/
    ├── dashboard_runtime_reconciler.dart
    ├── dashboard_runtime_diff.dart
    ├── dashboard_runtime_patch.dart
    └── zone_diff_engine.dart
```

### **Orchestration Duplication**
```
module_runtime_sync/
├── runtime_sync_engine.dart

dashboard_engine/application/
├── pipeline/
│   ├── runtime_pipeline_orchestrator.dart
│   ├── runtime_pipeline_context.dart
│   ├── runtime_pipeline_stage.dart
│   └── stages/
│       ├── reconciliation_stage.dart
│       ├── diff_stage.dart
│       ├── patch_stage.dart
│       └── execution_stage.dart
└── executor/smart_patch_coalescer.dart
```

---

## RESOLUTION COMPLEXITY RANKING

| Duplication | Fix Complexity | Breaking Changes | Timeline |
|---|---|---|---|
| contextProvider collision | HIGH | YES | Weeks |
| User context models | VERY HIGH | YES | Weeks |
| Reconciliation patterns | MEDIUM | NO (encapsulated) | Days |
| Pipeline orchestration | HIGH | MAYBE | Weeks |
| State mutation APIs | MEDIUM | YES | Days |
| Bootstrap coordination | HIGH | MAYBE | Weeks |

---

## PRODUCTION RISK FROM DUPLICATIONS

| Risk | Severity | Description |
|---|---|---|
| State sync failure | 🔴 CRITICAL | Two separate user context systems could diverge |
| Import collision | 🔴 CRITICAL | `contextProvider` from same package could be ambiguous |
| Type mismatch | 🔴 CRITICAL | Expecting `AppContext`, receive `EntityContext` or vice versa |
| Bootstrap order failure | 🟡 MAJOR | Unclear initialization order could fail at startup |
| Reconciliation inconsistency | 🟡 MAJOR | Different patterns applied to module vs dashboard state |
| API confusion | 🟡 MAJOR | Developers unsure which context API to use |
| Maintenance divergence | 🟡 MAJOR | Changes to one reconciler not reflected in other |
