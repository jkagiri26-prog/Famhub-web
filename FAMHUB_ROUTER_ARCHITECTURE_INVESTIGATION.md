# FAMHUB Router Architecture Investigation

**Date**: June 2026  
**Scope**: Analysis of two routing implementations — `AppRouter` vs `DynamicRouteRegistrar`  
**Status**: ✅ **Investigation Complete — No Code Changes Made**

---

## 1. Summary

Two separate routing systems exist in the codebase:

| System | File | Status |
|--------|------|--------|
| **AppRouter** | `lib/core/router/app_router.dart` | ✅ **Active** — Used via `appRouterProvider` |
| **DynamicRouteRegistrar** | `lib/core/composition/router/dynamic_route_registrar.dart` | ❌ **Inactive** — Not wired into any provider |

---

## 2. Which Router Is Currently Active?

**`AppRouter.createRouter()`** is the active routing system.

- `appRouterProvider` in `lib/core/router/app_router_provider.dart` calls `AppRouter.createRouter()`
- `MyApp.build()` in `lib/main.dart` uses `ref.watch(appRouterProvider)`
- The `DynamicRouteRegistrar.buildRouter()` method is **never called** anywhere in the production code path

---

## 3. Why Both Implementations Exist

The dual router system reflects an **incomplete architecture migration**:

- **AppRouter**: Original implementation — hardcoded all 16+ module routes + 6 system routes + guest route directly in GoRouter configuration. Built when the app was initially constructed with static routing.

- **DynamicRouteRegistrar**: Newer composition-engine-based implementation — builds routes dynamically from `ModulePageRegistry` (populated during bootstrap). Designed to dynamically include/exclude routes based on which modules are enabled at runtime.

The architecture migrated toward backend-driven feature management (composition engine, runtime sync), but `AppRouter` was never replaced.

---

## 4. Is DynamicRouteRegistrar Unfinished?

**Partially.** The implementation is **complete** for its purpose:

- ✅ `ModulePageRegistry` — static registry populated by `bootstrapModulePageBuilders()`
- ✅ `DynamicRouteRegistrar.buildRouter()` — builds GoRouter with `RuntimeModule` filtering
- ✅ `DynamicRouteRegistrar.rebuildRouter()` — alias for rebuild
- ✅ Correctly filters by `maintenanceMode`
- ✅ Includes system routes (Home, Search, Notifications, Reports, Settings, AI Assistant, Guest)
- ❌ **Not wired** to any Riverpod provider
- ❌ **Not integrated** into `appRouterProvider`

---

## 5. Does AppRouter Intentionally Own Root Navigation?

**Yes**, but by convention rather than by architecture.

- `AppRouter` was intentionally designed as the "single routing authority" (as noted in its doc comments)
- It owns the `ShellRoute` wrapping `UnifiedAppShellV2`
- It defines all routes: system routes, module routes, guest routes, and error handling
- However, `DynamicRouteRegistrar` also defines the same `ShellRoute` wrapper and duplicates system routes

The duplicate system routes (home, search, notifications, reports, runtime_settings, ai_assistant, guest) exist in **both** files with identical definitions.

---

## 6. Should DynamicRouteRegistrar Only Register Module Routes?

**This is the recommended migration path.**

The ideal architecture:
- **AppRouter** → Root navigation only (ShellRoute, error handling, initial redirects)
- **DynamicRouteRegistrar** → Module routes only (farm_management, marketplace, analytics, etc.)
- System routes (home, search, notifications, etc.) → Cleanly owned by **one** place

---

## 7. Is Backend-Driven Routing Partially Implemented?

**Yes.** The infrastructure is in place but not wired:

- ✅ `enabledRuntimeModulesProvider` in `descriptor_providers.dart` — resolves enabled modules with context filtering
- ✅ `enabledModuleRoutesProvider` in `composition_providers.dart` — returns `(moduleId, route)` tuples for enabled modules
- ✅ `ModulePageRegistry` — populated via `bootstrapModulePageBuilders()`
- ❌ No provider combines these into a `GoRouter`
- ❌ No reactive route rebuild when modules change

---

## 8. Migration Strategy Recommendation

### Long-Term Source of Truth

**`DynamicRouteRegistrar`** should become the sole route builder. It already has the architecture for:
- Backend-driven module enable/disable
- Maintenance mode filtering
- Consistent error handling
- Rebuild capability

### Migration Steps

This is **not approved for implementation yet** — only documented:

1. **Consolidate system routes** into `AppRouter` (or a shared config)
2. **Wire `DynamicRouteRegistrar.buildRouter()`** into `appRouterProvider`, passing `enabledRuntimeModulesProvider`
3. **Remove duplicate route definitions** from `AppRouter`
4. **Add reactive rebuild** via `runtimeModuleRegistryProvider` watcher
5. **Remove dead code** (`ModulePageRegistry` if unused, or keep for module-only registration)

### Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Route mapping mismatch | Medium | Verify all module IDs in `bootstrapModulePageBuilders()` match `AppRoutes` names |
| Missing routes | Medium | Compare both files' route lists |
| ShellRoute duplication | Low | Ensure single ShellRoute with single child |
| Error page disparity | Low | Both use identical error builders |
| Module ID drift | Low | Module IDs are hardcoded strings in both files |

---

## 9. Verification Checklist (Future Implementation)

- [ ] All 16 module routes present in `DynamicRouteRegistrar`
- [ ] All 6 system routes present
- [ ] Guest route present
- [ ] `ShellRoute` wrapper matches `AppRouter`
- [ ] `errorBuilder` matches `AppRouter`
- [ ] `initialLocation` matches
- [ ] Route names match `AppRoutes` constants
- [ ] No dead imports left
