# PHASE 1 AUDIT: RESPONSIBILITY MAP
**Audit Date**: May 28, 2026  
**Modules Audited**: core/module_runtime_sync, core/dashboard_engine, core/context, core/context_engine

---

## RESPONSIBILITY BREAKDOWN

### **module_runtime_sync**
**Primary Responsibility**: Module state lifecycle and real-time synchronization

| Responsibility | Implementation | Status |
|---|---|---|
| Listen for module state changes | Supabase realtime subscription on `modules` table | ✓ Active |
| Ingest PostgreSQL events | Event stream processor in `RuntimeSyncEngine` | ✓ Active |
| Track module states | `ModuleRuntimeState` model (activeModules, disabledModules, maintenanceModules) | ✓ Active |
| Apply reconciliation rules | `ModuleRuntimeReconciler` with deterministic state machine | ✓ Active |
| Resolve concurrent changes | `SmartPatchCoalescer` for conflict resolution | ✓ Active |
| Bootstrap module runtime | `RuntimeSyncEngine.initialize()` or via bootstrap coordinator | ✓ Active |
| Expose state to consumers | `moduleRuntimeSyncProvider` (StateNotifierProvider) | ✓ Active |
| Coordinate with dashboard engine | Calls to `DashboardRuntimeReconciler`, `DashboardRuntimeWatchdog`, `RuntimePipelineOrchestrator` | ⚠️ Bidirectional Dependency |

**Primary Concern**: Real-time module state synchronization

---

### **dashboard_engine**
**Primary Responsibility**: Dashboard composition, layout resolution, and render pipeline orchestration

| Responsibility | Implementation | Status |
|---|---|---|
| Build dashboard structure | `DashboardCompositionEngine` generates CompositionNode graph | ✓ Active |
| Generate composition from modules | Reads module definitions, outputs `CompositionSnapshot` | ✓ Active |
| Resolve layout per device type | `LayoutContext` evaluates (device, role, entityId) → layout decisions | ✓ Active |
| Group widgets by zone | `DashboardZoneComposer` creates header/main/sidebar groupings | ✓ Active |
| Generate reconciliation diffs | `DashboardRuntimeDiff` when module state changes | ✓ Active |
| Create patches | `DashboardRuntimePatch` defines state changes | ✓ Active |
| Execute patches on state | `SafeDashboardPatchExecutor` applies patches deterministically | ✓ Active |
| Orchestrate 4-stage pipeline | `RuntimePipelineOrchestrator` (reconciliation → diff → patch → execution) | ✓ Active |
| Render snapshot to widgets | `DashboardRenderer` + widget builder registry | ✓ Active |
| Provide widget builders | Bootstrap registers builders from system modules | ✓ Active |
| Monitor pipeline health | `DashboardRuntimeWatchdog` tracks execution | ✓ Active |
| Generate telemetry | Telemetry components collect metrics | ✓ Active |
| Manage prediction/intelligence | Prediction engine predicts layout changes | ✓ Active |
| Handle composition conflicts | Conflict resolution engine (strategy unclear) | ⚠️ Unclear Pattern |

**Primary Concern**: Dashboard structural rendering pipeline

---

### **context**
**Primary Responsibility**: Basic user/role context state management

| Responsibility | Implementation | Status |
|---|---|---|
| Store user identity | `UserContext` (userId, entityId) | ✓ Active |
| Store active role | `RoleContext` (activeRole enum) | ✓ Active |
| Track loading state | `AppContext.isLoading` boolean | ✓ Active |
| Provide state mutations | `ContextNotifier` (setUser, setRole, setLoading, reset) | ✓ Active |
| Expose state to UI | `contextProvider` (StateNotifierProvider) | ✓ Active |
| Maintain immutability | All updates create new AppContext instances | ✓ Active |

**Primary Concern**: In-memory user and role state

---

### **context_engine**
**Primary Responsibility**: User context lifecycle with persistence and backend sync

| Responsibility | Implementation | Status |
|---|---|---|
| Load context from storage | `ContextController.init()` → `ContextStorageService.load()` | ✓ Active |
| Apply context immediately | Fast UI feedback with local state | ✓ Active |
| Sync with backend | `ContextSyncService` fetches and merges remote context | ✓ Active |
| Persist context changes | `ContextStorageService.save()` for all state changes | ✓ Active |
| Switch roles persistently | `ContextController.switchRole()` with storage update | ✓ Active |
| Switch entities persistently | `ContextController.switchEntity()` with storage update | ✓ Active |
| Handle offline scenarios | Uses local state if network unavailable | ✓ Active |
| Logout and cleanup | `ContextController.logout()` → clear storage + reset state | ✓ Active |
| Provide context guards | `ContextGuardService` for authorization checks | ✓ Active |
| Expose state to consumers | `contextProvider` injecting ContextController | ✓ Active |

**Primary Concern**: User context persistence, sync, and lifecycle

---

## RESPONSIBILITY CLUSTERING

### **Synchronization Layer** (Real-time Updates)
- `module_runtime_sync`: Module state sync from Supabase
- `context_engine`: User context sync from backend
- `dashboard_engine`: Dashboard state updates (passive, reacts to module changes)

### **Orchestration Layer** (Pipeline Management)
- `dashboard_engine`: 4-stage render pipeline
- `module_runtime_sync`: Event-to-reconciliation pipeline
- `context_engine`: Bootstrap (load → apply → sync → persist) pipeline

### **State Representation Layer**
- `context`: Simple user/role model
- `context_engine`: Rich entity context model
- `module_runtime_sync`: Module state model
- `dashboard_engine`: CompositionNode/CompositionSnapshot

### **Persistence Layer**
- `context_engine`: Local storage and backend sync
- `module_runtime_sync`: Supabase realtime (read-only on client)
- `dashboard_engine`: In-memory only (derives from module state)

---

## RESPONSIBILITY GAPS & OVERLAPS

| Gap/Overlap | Description | Risk |
|---|---|---|
| **Context Duplication** | `context` and `context_engine` both manage user state; unclear which is primary | HIGH: Could cause state inconsistency |
| **Reconciliation Logic Duplication** | `ModuleRuntimeReconciler` and `DashboardRuntimeReconciler` follow similar patterns | MEDIUM: Code duplication, harder to maintain |
| **Pipeline Architecture** | Both `module_runtime_sync` and `dashboard_engine` have orchestrators | MEDIUM: Unclear if dependencies are correct |
| **Feature Flag Management** | Ingested by `module_runtime_sync` but source/lifecycle unclear | MEDIUM: Possible orphaned responsibility |
| **Layout Decision Strategy** | `dashboard_engine` owns device-based layout but strategy/rules not documented | MEDIUM: Implicit knowledge |
| **Bootstrap Coordination** | Multiple modules bootstrap independently; order/dependencies unclear | HIGH: Could cause initialization failures |

---

## RESPONSIBILITY MATRIX (Source of Responsibility)

| Responsibility | module_runtime_sync | dashboard_engine | context | context_engine |
|---|:-:|:-:|:-:|:-:|
| Module state tracking | ✓ | | | |
| Dashboard composition | | ✓ | | |
| Rendering decisions | | ✓ | | |
| User identity | | | ✓ | ✓ |
| Role management | | | ✓ | ✓ |
| Persistence | | | | ✓ |
| Backend sync | | | | ✓ |
| Context initialization | | | | ✓ |
| Event processing | ✓ | ✓* | | |
| Conflict resolution | ✓ | ✓* | | |

\* dashboard_engine handles dashboard-level events; module_runtime_sync handles module events
