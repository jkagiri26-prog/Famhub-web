# FAMHUB Runtime Architecture Verification

**Type:** Final READ-ONLY runtime verification (companion to `FAMHUB_APPLICATION_ARCHITECTURE_AUDIT.md`).
**Goal:** Separate LIVE runtime behavior from dead/orphaned/duplicate code before the canonical model migration
(`auth user → profile → active core.entity → membership → entity role → permissions → module access → data scope → nav/dashboard`).
**Rule applied:** nothing is classified DEAD/ORPHANED unless repository references / runtime consumers confirm zero reachable consumers. No code, SQL, or migrations touched.

Evidence was gathered by tracing `lib/main.dart` boot, and by `rg` consumer sweeps over all 784 Dart files. Key consumer greps are referenced inline.

---

## A. Runtime execution graph (verified live path)

```
main() ─ lib/main.dart:85-333
 ├─ Supabase.initialize(url, anonKey)                     main.dart:150-155
 ├─ ProviderContainer + platform store                    main.dart:174-178
 ├─ RuntimeSyncEngine() constructed                       main.dart:183-188
 ├─ bootstrapModulePageBuilders()    → ModulePageRegistry main.dart:238 / dynamic_route_registrar.dart:217-268
 ├─ module_descriptor_bootstrap      → 17 runtime descr.  main.dart:248 / module_descriptor_bootstrap.dart:50-71
 ├─ contributions bootstrap                                main.dart:262
 ├─ bootstrapPhaseD (WidgetRegistry)                      main.dart:278
 ├─ policies bootstrap                                     main.dart:290
 └─ runApp(UncontrolledProviderScope(MyApp))              main.dart:325-330

MyApp.build → SessionGate(_initialize)                    main.dart:459-476
SessionController.initialize()                            session_provider.dart:61-191
 ├─ client.auth.currentUser → users.profiles (by auth_user_id)   session_provider.dart:406-430
 ├─ users.user_workspaces  → workspaceIds                 session_provider.dart:434-451
 ├─ profiles.current_workspace_id → defaultWorkspaceId    session_provider.dart:157-158
 └─ AuthenticatedSession{userId,profile,workspaceIds,defaultWorkspaceId}  app_session.dart:161-228
resolveSessionDestination → splash|welcome|createProfile|workspaceSelection|dashboard
                                                                           session_destination.dart:50-70
 ├─ welcome  → SignInScreenPage (OTP)                     session_gate.dart (restore 93-104)
 ├─ createProfile → CreateProfilePage                     session_gate.dart:330
 ├─ workspaceSelection → WorkspaceSelectionPage           session_gate.dart:352
 └─ dashboard → authenticatedBuilder → MaterialApp.router(appRouterProvider)  session_gate.dart:167-168

[post-frame, main.dart:361 & 382]
 ├─ contextProvider.notifier.init()  → ContextController (SharedPrefs + ContextSyncService STUB)  main.dart:361
 └─ RuntimeSyncEngine.initialize()   → system.modules + system.module_installations realtime
                                                    runtime_sync_engine.dart:436-471 (NOT applied to module cache)

appRouterProvider = DynamicRouteRegistrar.buildRouter(runtimeModuleRegistryProvider)  app_router_provider.dart:28-31
 ├─ ShellRoute → UnifiedAppShellV2                       dynamic_route_registrar.dart:133-136
 ├─ '/'  → UnifiedDashboardHost                          :137-142
 │        └─ activeWorkspaceType → primary module page    unified_dashboard_host.dart:40-49
 │           farmer→FarmManagementPage / trader→BusinessHubPage / institution→FinancingPage
 ├─ /home,/search,/notifications,/reports,/settings,/ai-assistant,/guest,/profile/settings  :137-191
 ├─ /trader forced always                                  :122-128
 ├─ module routes (farm, marketplace, … /admin) only if module in DB-enabled runtimeModuleRegistry  :99-117
 └─ page resolution via ModulePageRegistry                :217-268

UnifiedAppShellV2 (watches runtimeAutoInvalidatorProvider)   new_unified_app_shell.dart:87-242, 101
 ├─ mobile         → ShellBottomNav                        mobile_shell_layout.dart:19
 │                   ├─ fixed 5 slots: Home|Marketplace|workspace-dashboard|Traceability|More   shell_bottom_nav.dart:56-113
 │                   ├─ slot3 + label from activeWorkspaceType        shell_bottom_nav.dart:130-169
 │                   └─ More sheet = dashboardNavItemsProvider − pinned + Profile  shell_bottom_nav.dart:50,96-113
 ├─ compact-xs     → dashboardNavItemsProvider             compact_xs_shell_layout.dart:94
 ├─ tablet         → ShellNavigationRail (sidebarNavItemsProvider)    shell_navigation_rail.dart:49
 └─ desktop/ultra  → ShellSidebar (sidebarNavItemsProvider)           shell_sidebar.dart:51 / desktop & ultra_wide layouts

NavItem providers (nav_config.dart)  dependency chain:
 sidebarNavItemsProvider :86 / bottomNavItemsProvider :107 / dashboardNavItemsProvider :128 /
 quickActionItemsProvider :149 / pinnedNavItemsProvider :169
  └─ watch: moduleProvider + contextProvider + activeWorkspaceTypeProvider   :88-176
       _buildNavItems → visibility flags → RuntimeFeatureFlags.evaluateModule → workspace scope   :193-233
            evaluateModule checks ONLY: enabled | maintenance | premium/tier(context.tier, defaults free) |
                                          entity(context.entityId=stub) | device           runtime_feature_flags.dart:88-161
            NO ROLE CHECK in nav path.

UnifiedDashboardHost fallback (unmapped type) → ResponsiveDashboardRenderer (dashboard_engine renderer, LIVE here)
                                                                          unified_dashboard_host.dart:52
```

**The canonical chain today is effectively:**
`auth user → users.profiles → workspace ids → active workspace TYPE (system.workspaces category) → module visibility from system.modules rows → nav/router.`
**The intended canonical chain (entity → membership → entity role → permission → data scope) does not exist at runtime.** It exists only as: stub context, dead RPC clients, and RLS-trusted data queries.

---

## B. LIVE components (reachable on the authenticated path)

| # | Component | Evidence (consumers) |
|---|---|---|
| 1 | `SupabaseService` / `Supabase.instance` | boot `main.dart:150`; used by all data sources |
| 2 | `SessionController`/`sessionProvider` + `AuthenticatedSession` | gate `session_gate.dart:81-84`; shell_app_bar, user_provider, active_workspace_provider, profile pages |
| 3 | `SessionGate` + `resolveSessionDestination` | `main.dart:459` |
| 4 | `appRouterProvider` → `DynamicRouteRegistrar` → `ModulePageRegistry` | `main.dart` router; `app_router_provider.dart:28-31` |
| 5 | `UnifiedAppShellV2` + layout switchers | shell page; layout imports (mobile/tablet/desktop/ultra/compact_xs) |
| 6 | `UnifiedDashboardHost` (workspace-type dispatch) | `/` route |
| 7 | `ShellSidebar` / `ShellNavigationRail` / `ShellBottomNav` | consumed by layouts |
| 8 | `nav_config` providers (sidebar/bottom/dashboard/quick/pinned) + `UnifiedNavBuilder` | consumed by 3 shells; invalidated by `runtime_refresh_provider.dart:45-93` |
| 9 | `runtimeAutoInvalidatorProvider` | `new_unified_app_shell.dart:101`; boot comment `main.dart:366` |
| 10 | `moduleProvider` → `ModuleService.getActiveModules` (`system.modules` select, 5-min cache) | `nav_config`, `composition_providers.dart`, `descriptor_providers`, shell_app_bar, bottom nav, `runtime_refresh_provider` |
| 11 | `runtimeModuleRegistryProvider` / `enabledRuntimeModulesProvider` (composition) | router (via appRouterProvider), `descriptor_providers.dart`, reports/settings/command palette/ai-assistant pages |
| 12 | `moduleWidgetDescriptorsProvider` → `WidgetRegistry.resolve` | `farm_management_page.dart:591,665-683`; `farm_home_page.dart:280` |
| 13 | `activeWorkspaceProvider`/`ActiveWorkspaceNotifier` (workspace id) | shell_app_bar selector, workspace_bridge, workspace_dashboard_provider |
| 14 | `activeWorkspaceTypeProvider` / `WorkspaceDashboardCatalog` (type → module promotion) | `shell_bottom_nav.dart`, `unified_dashboard_host.dart`, `nav_config.dart` |
| 15 | `contextProvider`/`ContextController`/`EntityContext` (as trigger object) | watched by nav_config, composition, capability, governance, validators — **but its role/entity/tier payload is the stub** (see C) |
| 16 | `capabilityProfileProvider` (role→capability local mapping) | `business_hub_page.dart:221`, `business_hub_overview_tab.dart:113`, `business_hub_section_boundary.dart:43`, `business_hub_operations_widget.dart:95` |
| 17 | `activeBusinessProvider`/`myBusinessesProvider`/`BusinessMember` (`core.entities`/`entity_members`) | 15 business_hub widgets/providers (verified) |
| 18 | `farmContextProvider` + hierarchy/selected farm | 24 farm_management files (verified) |
| 19 | Feature module landing pages + their data providers | routes resolve from ModulePageRegistry |
| 20 | `RuntimeSyncEngine` (module_runtime_sync) | boot `main.dart:382`; output → syncStateProvider icon + validator provider (minor, not nav) |

---

## C. PARTIALLY LIVE components (real consumers but wrong/fake/partial input, or only part of the intended path is active)

| Component | Reality | Evidence |
|---|---|---|
| `contextProvider` / `EntityContext` / `ContextController` | LIVE as an invalidation trigger and provider input, but `role:'farmer'`, `entityId:'farm_123'`, `userId:'server_user_id'` are **hard-coded** by `ContextSyncService.fetchUserContext` | `context_sync_service.dart:6-10`; init `main.dart:361`; prefs seeded at `context_controller.dart:25-54` |
| `ContextStorageService` (SharedPreferences `ctx_user/ctx_role/ctx_entity/ctx_tier`) | Written/read by ContextController (live), but the write is overwritten by the stub right after | `context_controller.dart:20-55`, `context_storage_service.dart:4-19` |
| `RuntimeFeatureFlags.evaluateModule` | LIVE in nav path (via `_buildNavItems`), but checks no role; tier read from stub context (`'free'` default); premium/entity flags parse from DB keys that don't match backend DDL | `nav_config.dart:214-218`; `runtime_feature_flags.dart:88-161`; `system_module.dart:90-124` vs `docs/Backend schemas/system_schema.md:12-31` |
| `RuntimeSyncEngine` | LIVE (subscribes + reconciles `ModuleRuntimeState`), but **never invalidates `ModuleService` cache** → toggle doesn't reach nav | `runtime_sync_engine.dart:436-471`; no caller of `ModuleService.refreshModules()/invalidateCache()` |
| Composition contribution stack (`descriptor_providers`, contribution providers) | PARTIALLY LIVE: powers module route list (router) + descriptor-driven farm dashboard widgets + settings/reports/ai/command-palette lists. Its `CompositionNavItem`s are NOT consumed by any shell | `shell_sidebar`/`shell_bottom_nav`/`compact_xs` read only nav_config providers |
| `capabilityProfileProvider` | LIVE in Trader UI but **derives from `context.role` (the stub `'farmer'`)**, not the active business entity → every user gets `basicFarmer` preset regardless of entity/membership | `capability_profile_provider.dart:43-57,78-109` (header warns TEMPORARY `:73-77`) |
| `workspace` domain (tabs/layout/shellMode OS model) | Workspace id/type is LIVE; the tabs/layout/history/`openTabsProvider` portion has **no UI consumer** | only id→type→promotion chain is consumed (B-13/14) |
| Access tree (`accessPolicyProvider`/`AccessDecisionEngine`/`runtimeDecision*`/`AccessSdk`/`CapabilitySdk`/`featureAccessProvider`/`accessStateProvider`) | Wired together (policy RPC → engine → SDK) but reach the UI **only** through `FeatureGate`, which has **zero widget consumers**; invalidated by organization provider only | consumer sweep: only `feature_gate_widget.dart` + `active_organization_provider.dart:166-174`; `FeatureGate` has no other usage |

---

## D. DEAD / ORPHANED components (zero reachable runtime consumers)

Verified by full-repo reference sweeps (importers/consumers absent outside own file/test):

| Component | Where | Notes |
|---|---|---|
| `FeatureGate` | `lib/shared/widgets/gates/feature_gate_widget.dart` | sole gate widget; zero consumers |
| `RouteSafetyNavigator` (`safeGo/safePush`) | `lib/core/router/route_validation/route_safety_navigator.dart` | zero consumers |
| `DashboardRuntimeValidator` static-role path | `dashboard_engine/application/validation/dashboard_runtime_validator.dart:192-208` | referenced only from provider feeding validators with no widget consumers |
| `lib/core/guards/*` (`auth_guard`, `profile_guard`, `role_guard`) | 0-byte placeholders | nothing to run |
| `permission_service.dart` | 0 bytes | never implemented |
| `admin_console/domain/permissions/permissions.dart` | 0 lines | empty |
| `AuthProvider` (Hive `auth_cache`) | `lib/core/providers/auth_provider.dart` | orphan, never instantiated outside file |
| `RoleSelectionScreenPage` (13-role onboarding) | `features/auth/.../role_selection_screen_page.dart` | **zero references** (verified) |
| `access_policy_sync_service.dart` (realtime `access_policy_changes`) | `core/access/infrastructure/sync/` | no start/reference; also unqualified public-schema stream |
| feature_flags repos `module/access/subscription` (RPCs `get_enabled_modules`, `get_access_context`, `get_subscription_state`) | `core/feature_flags/infrastructure/repositories/` + `core/modules/.../module_repository.dart` | no consumers |
| `SubscriptionRepository`/`setTier`/`subscriptionProvider` tier mutation | `core/subscription/**` | `setTier` no callers → tier stuck `free` |
| `RemoteConfigService` (dummy config) + `remoteConfigProvider` | `core/config/remote_config/**` | no consumers |
| `CompositionNavBuilder`/composition nav items | `core/composition/navigation/composition_nav_builder.dart` | produced but never rendered |
| `DynamicCompositionEngine` + `evaluateWidget`/`evaluateSection` (widget role gates) | `dashboard_engine/application/composition/dynamic_composition_engine.dart:82-95` | no consumers → **role-gated widgets are inert** |
| `FloatingActionButtonHost` | composition/…/floating_action_button_host.dart | watches `runtimeModuleRegistryProvider` but zero widget consumers |
| Orphan `ContextNotifier` | `context_engine/controllers/context_notifier.dart` | duplicate; `context_provider` uses `ContextController` |
| Duplicate `moduleAccessProvider` (governance) | `feature_flags/.../governance_provider.dart:91` | second definition unused |
| Legacy `MarketplaceService` (`@Deprecated`, public `listings`) | `features/marketplace/infrastructure/services/marketplace_service.dart` | deprecated; data source is the live path |
| Legacy `app_router.dart` shim | `lib/core/router/app_router.dart:54-64` | delegates to registrar; not the live provider |
| `lib/app/app.dart` | empty | |
| `HomePage` (features/home) / `FarmHomePage` alternate landing | `features/home`; `farm_management/presentation/pages/farm_home_page.dart` | not wired to routes/module registry (its `moduleWidgetDescriptorsProvider` read is unreachable) |
| Static catalogs `FeatureRegistry`, `AccessRegistry`, `DependencyRegistry`, `RouteRegistry` | `lib/system/registry/` | consumed only by other dead code/validators (AccessRegistry feeds RouteSafetyNavigator + DashboardRuntimeValidator, both dead) |
| Spatial layer | `core/spatial/**` | repository consumers exist only inside spatial engine/provider chain — verify reachability; queries also unqualified-schema (default `public`) — see audit §G |

---

## E. DUPLICATE systems (parallel implementations of the same concern)

1. **Two module fetchers:** `ModuleService` (`system.modules` select + 5-min cache — LIVE) vs `ModuleRepository.fetchEnabledModules` RPC `get_enabled_modules` (DEAD). `module_repository_provider.dart:13-21` (dead) vs `module_provider.dart:19-32` (live).
2. **Two "current role" holders that disagree:** `EntityContext.role` (`'farmer'` stub) vs `AppUser.role` = `session.selectedRoles.first` = **workspace id** (`user_provider.dart:32-34`, `session_provider.dart:384-386`). Live app bar shows the workspace id as role (display-only, `shell_app_bar.dart:51`).
3. **Three navigation stacks:** live `nav_config` providers (rendered), composition `CompositionNav*` (rendered by nobody), and `dashboard_engine` renderers — of which only `ResponsiveDashboardRenderer` is LIVE (fallback under `UnifiedDashboardHost`). The `dashboard_engine` pipeline (snapshot/diff/executor/recovery/etc.) has no live consumers outside the module_runtime_sync adapter.
4. **Two context controllers:** `ContextController` (live) vs `ContextNotifier` (orphan).
5. **`moduleAccessProvider` defined twice** (governance + composition providers); `module_access_filter.dart` duplicated at `core/composition/engine/` and `core/context_engine/services/`.
6. **Permission syntax in three grammars** (dot `module.action`; colon `admin:view`; underscore `view_feature`) — no shared constants.
7. **Capability profile** (client role→capability preset) vs DB membership flags (`can_manage`/`can_sell`/`can_receive_payments` — fetched, display-only) vs `AccessRegistry` static lists — three unrelated models of "what can this user do."

---

## F. Admin access path (verified)

```
system.modules row 'admin_console' (is_enabled=true, no maintenance)
  → ModuleService.getActiveModules()          module_service.dart:44-137
  → moduleProvider                            module_provider.dart
  → runtimeModuleRegistryProvider → buildRouter registers '/admin'  dynamic_route_registrar.dart:99-117 (page :252 AdminDashboardPage)
  → AdminDashboardPage renders (no auth check)                       admin_dashboard_page.dart:9+
  → AdminGovernanceService RPCs: update_feature_flag / toggle_module /
        update_role_permission / update_feature_tier                 admin_governance_service.dart:6-41
        via admin_service_provider.dart → tiles
```

**What blocks an ordinary authenticated user today:**
- **Nothing client-side.** No `isAdmin`, no role check on page or route, no guard (GoRouter has no redirects; `RouteSafetyNavigator` is DEAD).
- **Only incidental blockers:**
  1. `/admin` is registered **only if a `system.modules` row for `admin_console` exists and is enabled** in the DB (`module_service.dart:44-137`; `dynamic_route_registrar.dart:99-117`). If no such row → route absent → 404 for everyone. (Static `module_registry.dart:295-297` marks it disabled by default but that static catalog is not the router source.)
  2. `admin_console` appears in **no nav list** (`nav_config.dart:56-90` workspace-agnostic set + promotions), so it is unreachable from sidebar/bottom-nav/More; only direct URL `/admin`.
  3. Static `AccessRegistry` rule `admin_console → ['admin','super_admin'], tier enterprise` (`access_registry.dart:44-53`) feeds only DEAD validators.
- **Protection, if any, is entirely backend** (RLS / security-definer on the 4 admin RPCs and on `system.modules`/`system.feature_flags`). **Do not ship an Admin surface assuming client gating — today there is none.**
- **Runtime effect of enabling the row:** every authenticated user reaching `/admin` would see governance controls and be able to trigger the 4 RPCs. Verified `AdminDashboardPage` contains zero authorization code.

---

## G. Canonical migration impact map (which LIVE components change when backend context is introduced)

Introducing `active core.entity + membership + entity role + permissions` means the runtime must shift its input from **workspace type / stub context** to **entity-context**. Dependency direction (arrow = consumes):

```
auth user ── users.profiles ──▶ SessionController (LIVE)
                                 │  workspaceIds / defaultWorkspaceId   ← will be superseded by user_workspaces(entity links)+current entity
                                 ▼
activeWorkspaceProvider (LIVE) ──type──▶ activeWorkspaceTypeProvider (LIVE)   [migration: derive workspace from active ENTITY context, not system.workspaces category]
   │                                        │
   │                                        ├──▶ UnifiedDashboardHost (LIVE)  → primary module page   [change: key off entity_type / role]
   │                                        └──▶ nav_config _scopeToWorkspace (LIVE)                  [change: scope by entity + role-permission]
   ▼
moduleProvider ── ModuleService(system.modules) (LIVE)                        [change: replace/augment with role-scoped get_enabled_modules + get_access_context]
   │
   ├──▶ runtimeModuleRegistryProvider (LIVE→router routes, descriptor dashboards)  [change: filter by access decision, not global is_enabled]
   ├──▶ descriptor_providers → WidgetRegistry dashboards (LIVE)                     [minor]
   └──▶ RuntimeFeatureFlags.evaluateModule (LIVE)                                   [add role/tier from backend]
   ▼
nav_config providers (LIVE, rendered by 3 shells)                                  [consume access-policy, not just flags]
   ▲
contextProvider / EntityContext (PARTIAL-LIVE: currently stub)                    [**must** become real: entity_context_sessions + active_role_id + business_profile_id]
   │
   ├──▶ capabilityProfileProvider (LIVE in Trader UI)                              [replace local role→capability preset with backend profile]
   ├──▶ business_hub widgets + BusinessMember (LIVE, id-based, correct seed)       [gates: adopt can_manage/can_sell/can_receive_payments + role permissions]
   └──▶ runtime invalidation (runtimeAutoInvalidatorProvider)                      [retain]
```

**Components that DO NOT need to change:** `SessionGate` flow shape, `SupabaseService`, shells/layouts, `DynamicRouteRegistrar` mechanism (its data input changes), farm_management/business_hub page shells, `WidgetRegistry` contribution pattern.

**Ordering constraint (why the DB audit gates this):** every LIVE consumer above currently trusts either the stub context or RLS. Converging the client before the backend contract exists would just relocate the stub.

---

## H. Recommended first 5 code changes after the backend contract is ready

1. **Make `EntityContext` real.** Replace `ContextSyncService.fetchUserContext` stub with a call to the canonical context RPC (`core.entity_context_sessions`/`get_access_context`) that returns `{entity_id, role_id→role_key, active_mode, business_profile_id, tier}`; persist via existing `ContextStorageService` prefs; keep `contextProvider` as the single invalidation root.
2. **Fix `AppUser.role`.** Stop overloading `selectedRoles` with workspace ids (`session_provider.dart:384-386`); source display role from real context. (Follow-on: retire the orphan `RoleSelectionScreenPage` only after context carries roles.)
3. **Adopt role-scoped module resolution.** Wire the already-written repos/RPCs (`get_enabled_modules`, `get_access_context`, `get_access_policy`, `get_subscription_state`) into `moduleProvider`/`runtimeModuleRegistryProvider`, fix `SystemModule.fromMap` to backend DDL keys, and make `RuntimeSyncEngine` invalidate `ModuleService` cache so admin toggles apply immediately.
4. **Replace `capabilityProfileProvider`'s local role→preset mapping** (`capability_profile_provider.dart:78-109`) with the backend entity-capability profile keyed by the real active entity, and start enforcing membership flags (`can_manage`, `can_sell`, `can_receive_payments`) in business_hub gates.
5. **Introduce one real route/nav authorization guard on the LIVE stack** (shell/`DynamicRouteRegistrar`), backed by the access decision; gate `/admin` with it (role/permission from context), add `admin_console` to a role-scoped nav item list, and delete the dead parallel `AccessRegistry`/`RouteSafetyNavigator`/`DashboardRuntimeValidator` role-name checks only after the new guard is proven.

**Explicit non-goals for those 5 changes:** no renames of existing providers/classes beyond their internals, no schema/migration work, no removal of old provider files until live replacement lands (see D/E for the full retirement list to revisit after convergence).

---

*Methodology: boot-path trace (main.dart → gate → router → shell → nav → dashboard → gates) plus full-repo consumer `rg` sweeps for every provider/class listed. Classifications B–E are backed by reference evidence; anything not confirmed to have zero consumers is kept PARTIALLY LIVE, never deleted.*
