# PHASE 1 AUDIT: SOURCE-OF-TRUTH MAP
**Audit Date**: May 28, 2026  
**Modules Audited**: core/module_runtime_sync, core/dashboard_engine, core/context, core/context_engine

---

## SOURCE OF TRUTH DEFINITION
**Source of Truth (SOT)**: The authoritative module that owns data state, applies mutations, persists changes, and resolves conflicts. Consumers should read from SOT; writes should route through SOT.

---

## SOURCE OF TRUTH REGISTRY

### **User Identity (userId, entityId)**

| Attribute | Candidate SOT | Evidence | Verdict |
|-----------|---|---|---|
| User ID | `context_engine` | Loads from storage, syncs with backend, persists changes | ✓ **WINNER** |
| | `context` | Simple in-memory model, no persistence | ✗ Insufficient |
| Entity ID | `context_engine` | `switchEntity()` with persistence | ✓ **WINNER** |
| | `context` | Simple setter, no persistence | ✗ Insufficient |

**Source of Truth**: **`context_engine`**

**Reasoning**:
- `context_engine` has storage integration (`ContextStorageService`)
- `context_engine` has backend sync (`ContextSyncService`)
- `context_engine` has lifecycle management (`init()`, `logout()`)
- `context` is stateless/ephemeral by design
- Persistent app state should not be managed by `context`

**Risk**: ⚠️ **CONFLICTING OWNERSHIP** — both modules export `contextProvider`; unclear which consumers should use

**Consumer Flow** (IDEAL):
```
App Start
  ↓
context_engine.ContextController.init()
  → load from storage
  → sync with backend
  → expose via contextProvider
  ↓
All consumers read from context_engine.contextProvider
```

**Actual Flow** (UNKNOWN):
```
App Start
  ↓
context.contextProvider or context_engine.contextProvider? ← UNCLEAR
  → State inconsistency risk
```

---

### **Active User Role**

| Attribute | Candidate SOT | Evidence | Verdict |
|-----------|---|---|---|
| Active role | `context_engine` | `switchRole()` with persistence + sync | ✓ **WINNER** |
| | `context` | Simple in-memory, no persistence | ✗ Insufficient |

**Source of Truth**: **`context_engine`**

**Reasoning**:
- Role changes must persist across app restarts
- Role changes must sync with backend
- `context` has no mechanism for persistence
- `context_engine` designed for role lifecycle

**Consumer Pattern** (IDEAL):
```dart
// Switching role
context_engine.switchRole(UserRole.trader)
  → persist locally
  → sync with backend
  → update provider state
  → UI reflects change

// Reading current role
final role = ref.watch(contextProvider).role
```

**Risk**: 🔴 If app uses `context.contextProvider`, role changes won't persist

---

### **Module Runtime State**

| Artifact | Owner | Persistence | Sync | Mutations |
|---|---|---|---|---|
| Active modules | `module_runtime_sync` | Supabase (server) | Realtime subscription | Server → client |
| Disabled modules | `module_runtime_sync` | Supabase (server) | Realtime subscription | Server → client |
| Maintenance modules | `module_runtime_sync` | Supabase (server) | Realtime subscription | Server → client |
| Module events | `module_runtime_sync` | N/A (ephemeral) | Supabase events | Server → client |

**Source of Truth**: **`module_runtime_sync`**

**Reasoning**:
- Module state originates from Supabase `modules` table (server source)
- `module_runtime_sync` subscribes to realtime changes
- Local state is read-only projection of server state
- Client cannot mutate directly; server is authority

**Consumer Pattern**:
```dart
// Read current module runtime state
final moduleState = ref.watch(moduleRuntimeSyncProvider)
  → activeModules
  → disabledModules
  → maintenanceModules

// Changes come from:
// 1. Supabase table updates (server action)
// 2. Event stream (PostgreSQL LISTEN)
// 3. No direct client mutations
```

**Clarity**: ✓ Clear — unidirectional from Supabase

---

### **Dashboard Composition**

| Artifact | Owner | Persistence | Sync | Mutations |
|---|---|---|---|---|
| CompositionNode graph | `dashboard_engine` | In-memory only | Derived from module state | Reconciliation engine |
| Composition snapshot | `dashboard_engine` | In-memory only | Generated per change | Composition engine |
| Widget builder registry | `dashboard_engine` | In-memory only | Bootstrap only | Bootstrap coordinator |
| Zone groupings | `dashboard_engine` | In-memory only | Per snapshot | Zone composer |

**Source of Truth**: **`dashboard_engine`**

**Reasoning**:
- Composition is derived from module state (not independent)
- Dashboard is read-only to consumers (no direct mutations)
- Changes trigger reconciliation → diff → patch → execution pipeline
- State is computed, not persisted

**Consumer Pattern**:
```dart
// Read current dashboard composition
final snapshot = ref.watch(compositionProvider)
  → nodes (list of CompositionNode)
  → index (lookup table)
  → zoneIndex (by zone)

// Changes flow:
// 1. Module state changes
//    ↓
// 2. dashboard_engine.reconcile() detects diff
//    ↓
// 3. dashboard_engine.patch() applies changes
//    ↓
// 4. compositionProvider updates
//    ↓
// 5. UI re-renders
```

**Clarity**: ✓ Clear — read-only derived state

---

### **Context Initialization State**

| Artifact | Owner | Persistence | Sync | Status |
|---|---|---|---|---|
| isLoading | `context` | No (in-memory) | No | Simple flag |
| | `context_engine` | No (in-memory) | Implicit in init() | Lifecycle signal |

**Source of Truth**: **AMBIGUOUS** ⚠️

**Reasoning**:
- `context.isLoading` is simple state mutation
- `context_engine` infers loading from `init()` lifecycle
- Not the same thing:
  - `context.isLoading` = user requested loading state
  - `context_engine` loading = bootstrap in progress
- Two different concepts conflated

**Risk**: 🟡 If consumers check `isLoading`, might check wrong module

**Consumer Confusion Example**:
```dart
// Option A (from context)
bool isLoading = ref.watch(contextProvider).isLoading
// → Manual state tracking, might be outdated

// Option B (from context_engine)
// → No explicit isLoading; infer from state presence
// → Implicit, harder to track
```

---

### **Event Stream**

| Event Type | Source | Processor | SOT |
|---|---|---|---|
| Module state changed | Supabase `modules` table | `module_runtime_sync` | Supabase server |
| Dashboard composition changed | Module state change | `dashboard_engine` | `module_runtime_sync` (derivative) |
| User context changed | Backend API | `context_engine` | Backend API |
| Feature flag changed | Module events | `module_runtime_sync` | Source unclear |

**Source of Truth per Event**:

**Module Events**: Supabase
```
Supabase modules table update
  ↓ PostgreSQL LISTEN
  ↓ Supabase realtime event
  ↓ module_runtime_sync.RuntimeSyncEngine
  ↓ ModuleRuntimeState update
  ↓ Consumers notified
```

**Dashboard Events**: `module_runtime_sync` (derivative)
```
module_runtime_sync.ModuleRuntimeState change
  ↓ dashboard_engine observes change
  ↓ Triggers reconciliation pipeline
  ↓ CompositionSnapshot update
  ↓ Consumers notified
```

**Context Events**: Backend API
```
Backend API endpoint
  ↓ context_engine.ContextSyncService
  ↓ Fetches remote context
  ↓ EntityContext update
  ↓ Persists to storage
  ↓ Consumers notified
```

---

## SOURCE OF TRUTH HIERARCHY

```
┌─────────────────────────────────────────────────────────────┐
│ Tier 0: External Sources (Server of Record)                 │
├─────────────────────────────────────────────────────────────┤
│ • Supabase modules table (Module Runtime SOT)               │
│ • Backend API (Context SOT)                                 │
│ • Feature flag service (Feature Flag SOT - UNCLEAR)         │
└─────────────────────────────────────────────────────────────┘
         ↓           ↓                    ↓
┌────────────────┐  ┌──────────────────┐ ┌──────────────────┐
│   Tier 1A:     │  │   Tier 1B:       │ │   Tier 1C:       │
│   Real-time    │  │   Sync-on-demand │ │   Derived State  │
│   Projection   │  │   Projection     │ │                  │
├────────────────┤  ├──────────────────┤ ├──────────────────┤
│module_runtime_ │  │ context_engine   │ │dashboard_engine  │
│sync            │  │ (EntityContext)  │ │(CompositionNode) │
└────────────────┘  └──────────────────┘ └──────────────────┘
         ↓                   ↓                    ↓
      Exposed via         Exposed via         Exposed via
   moduleRuntimeSync   contextProvider    compositionProvider
      Provider          (COLLISION!)            (13 providers)
         ↓                   ↓                    ↓
     Consumers          Consumers           Consumers
   (Read-only)         (Read-only)         (Read-only)
```

---

## SOURCE OF TRUTH CONFLICTS

| Artifact | Conflict | Severity | Root Cause |
|---|---|---|---|
| **User Identity** | `context` vs `context_engine` | 🔴 CRITICAL | Duplicate models, both export contextProvider |
| **Active Role** | `context` vs `context_engine` | 🔴 CRITICAL | Duplicate models, persistence gap |
| **Context Sync** | Unknown who syncs | 🔴 CRITICAL | Unclear which module is responsible |
| **Feature Flags** | Unknown source | 🟡 MAJOR | Ingested by module_runtime_sync but origin unclear |
| **Loading State** | `context` vs `context_engine` | 🟡 MAJOR | Different semantics, same name |
| **Bootstrap Order** | Three independent paths | 🟡 MAJOR | Unclear dependencies and execution order |

---

## CONSUMERS' SOURCE OF TRUTH CONFUSION

### **Current State: Ambiguous**

```dart
// Widget Consumer Pattern A (Using context)
final appContext = ref.watch(contextProvider);  // From context module
→ Returns AppContext with UserContext + RoleContext
→ No persistence guarantees
→ isLoading is manual flag

// Widget Consumer Pattern B (Using context_engine)
final entityContext = ref.watch(contextProvider);  // From context_engine module
→ Returns EntityContext (userId, role, entityId, isGuest, isLoading)
→ Persisted & synced
→ isLoading from bootstrap lifecycle

// Same provider name, different types!
// Compiler error if both imported:
// Error: contextProvider is ambiguous; could be from context or context_engine
```

### **Ideal State: Clear Provider Hierarchy**

```dart
// (1) Load app context
final entityContext = ref.watch(context_engine.contextProvider);

// (2) Load module runtime
final moduleState = ref.watch(module_runtime_sync.moduleRuntimeSyncProvider);

// (3) Load dashboard
final snapshot = ref.watch(dashboard_engine.compositionProvider);

// (4) Derived: is everything initialized?
final isReady = 
  entityContext.userId != null &&
  moduleState.activeModules.isNotEmpty &&
  snapshot.nodes.isNotEmpty;
```

---

## SOURCE OF TRUTH AUTHORITY MATRIX

| Concept | Authority | Persistence | Sync | Mutability | Conflicts |
|---|---|---|---|---|---|
| Module State | Supabase → module_runtime_sync | ✓ Server | ✓ Realtime | Client read-only | NO |
| Dashboard Comp. | module_runtime_sync → dashboard_engine | ✗ Ephemeral | ✓ Derived | Client read-only | NO |
| User Identity | Backend API → context_engine | ✓ Local + server | ✓ On-demand | Client-initiated (syncs back) | ✓✓ YES |
| Active Role | Backend API → context_engine | ✓ Local + server | ✓ On-demand | Client-initiated (syncs back) | ✓✓ YES |
| Context State | context or context_engine? | ? | ? | ? | ✓✓✓ YES |

---

## PRODUCTION BLOCKERS FROM SOT AMBIGUITY

| Blocker | Severity | Impact | Resolution |
|---|---|---|---|
| contextProvider collision | 🔴 CRITICAL | Import ambiguity, type mismatch at runtime | Rename one provider or modules |
| Two user context models | 🔴 CRITICAL | State divergence, consumer confusion | Consolidate to single model |
| Unknown feature flag SOT | 🟡 MAJOR | Feature flag updates unreliable | Clarify ingestion source |
| Unclear bootstrap order | 🟡 MAJOR | Initialization failures | Document dependency graph |
| isLoading semantic mismatch | 🟡 MAJOR | Improper loading UI | Rename or clarify semantics |
| No persistence contract | 🟡 MAJOR | Data loss on app restart | Explicitly contract context_engine as persistence layer |

---

## SOURCE OF TRUTH RECOMMENDATIONS (AUDIT ONLY)

✓ **Clear SOTs**:
- Module Runtime State → `module_runtime_sync` (via Supabase)
- Dashboard Composition → `dashboard_engine` (via module state)

⚠️ **Ambiguous SOTs** (requiring investigation):
- User Identity & Role → `context` or `context_engine`?
- Feature Flags → Source undefined
- Context Initialization → Explicit lifecycle needed
- Bootstrap Coordination → Dependency graph needed

🔴 **Conflicting SOTs** (blocking production):
- contextProvider name collision
- Two context notifier classes
- Unclear persistence contract
