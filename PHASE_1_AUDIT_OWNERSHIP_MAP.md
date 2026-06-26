# PHASE 1 AUDIT: OWNERSHIP MAP
**Audit Date**: May 28, 2026  
**Modules Audited**: core/module_runtime_sync, core/dashboard_engine, core/context, core/context_engine

---

## OWNERSHIP BREAKDOWN

### **module_runtime_sync**
**Owns:**
- Module runtime state lifecycle (active/disabled/maintenance flags)
- Real-time synchronization with Supabase `modules` table
- PostgreSQL change event ingestion and processing
- State reconciliation logic for module status transitions
- Event model definitions (moduleUpdated, installationUpdated, permissionUpdated, featureFlagUpdated)
- `RuntimeSyncEngine` orchestrator
- `ModuleRuntimeSyncProvider` (Riverpod StateNotifierProvider)
- Bootstrap coordination for module runtime initialization

**Does NOT own:**
- Dashboard composition or layout
- User/role context management
- Widget rendering or presentation

---

### **dashboard_engine**
**Owns:**
- Dashboard composition (building structure from modules)
- CompositionNode graph generation
- Layout resolution (device-aware rendering decisions)
- Zone management (header, main, sidebar grouping)
- Dashboard-level reconciliation (diffs from composition changes)
- Patch generation and patch execution strategy
- 4-stage runtime pipeline orchestration (reconciliation → diff → patch → execution)
- Widget builder registry and bootstrap
- Presentation rendering facade (`DashboardRenderer`)
- 13 Riverpod providers (composition, reconciliation, patch, rendering, watchdog, telemetry)

**Does NOT own:**
- Module state or module synchronization
- User/role context (consumes from context layers)
- Low-level data persistence

---

### **context**
**Owns:**
- Basic user context model (`UserContext`: userId, entityId)
- Role context model (`RoleContext`: activeRole enum)
- Simple state mutation API (setUser, setRole, setLoading)
- `contextProvider` (Riverpod StateNotifierProvider)
- `ContextNotifier` lightweight state notifier

**Does NOT own:**
- Persistence/storage
- Backend synchronization
- Entity switching
- Complex context lifecycle

---

### **context_engine**
**Owns:**
- Entity context model (`EntityContext`: userId, role, entityId, isGuest, isLoading)
- Local storage integration (`ContextStorageService`)
- Backend sync integration (`ContextSyncService`)
- Context bootstrap from storage
- Offline fallback behavior
- Role switching with persistence
- Entity switching with persistence
- Logout with cleanup
- `ContextController` advanced state notifier
- `contextProvider` (Riverpod provider injecting ContextController)
- Context guards/authorization services

**Does NOT own:**
- Module state
- Dashboard composition
- Low-level database operations

---

## OWNERSHIP CONFLICTS

| Conflict | Module A | Module B | Issue |
|----------|----------|----------|-------|
| **User Context Management** | `context` | `context_engine` | Both manage user/role state; `context_engine` more advanced but both exported as providers |
| **Provider Naming** | `context` | `context_engine` | Both export `contextProvider` — potential import collision |
| **State Notifier** | `context.ContextNotifier` | `context_engine.ContextNotifier` | Duplicate class name and responsibility |
| **Reconciliation** | `module_runtime_sync.ModuleRuntimeReconciler` | `dashboard_engine.DashboardRuntimeReconciler` | Different concerns but similar patterns; unclear if they conflict |

---

## OWNERSHIP CLARITY MATRIX

| Artifact | Clear Owner | Ambiguous |
|----------|:-----------:|:---------:|
| Module runtime state | ✓ module_runtime_sync | |
| Dashboard composition | ✓ dashboard_engine | |
| User identity (userId, entityId) | | ✓ context vs context_engine |
| Role state | | ✓ context vs context_engine |
| Context persistence | ✓ context_engine | |
| Context sync | ✓ context_engine | |
| Event processing | ✓ module_runtime_sync | |
| Widget rendering | ✓ dashboard_engine | |
| Patch orchestration | ✓ dashboard_engine | |

---

## UNOWNED ARTIFACTS
- Device-specific layout decisions (owned by dashboard_engine but no module decides platform strategy)
- Module feature flags (ingested by module_runtime_sync but source/management unclear)
