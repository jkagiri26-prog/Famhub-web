# FAMHUB Application Architecture Audit

**Scope:** Flutter/Dart consumer audit — identity, workspace/entity, roles, permissions, module access, navigation, data filtering and backend RPC dependencies.

**Repo:** `Famhub-web` (supabase_flutter ^2.12.0, Riverpod ^3.3.2, go_router ^14.8.0) — 784 Dart files under `lib/`, ~121k LOC.

**Companion doc:** Database architecture audit (backend). This document is the application-consumer portion. Nothing was modified — audit only.

**Status:** READ-ONLY audit + dependency map. No Dart or SQL changed.

---

## 0. Executive summary

FamHub authenticates one Supabase identity and surfaces it through **four disconnected client-side "current context" singletons**:

1. `AuthenticatedSession` (profile + workspace ids) — `lib/core/session/app_session.dart:161`
2. `ActiveWorkspace` (`system.workspaces` row id + derived type farmer/trader/institution) — `lib/core/workspace/application/active_workspace_provider.dart:56`
3. `EntityContext.role/entityId/tier` (Context engine) — **fed by a hard-coded stub** — `lib/core/context_engine/services/context_sync_service.dart:6-10`
4. `ActiveBusiness` / farm-hierarchy `entityId` — `lib/features/business_hub/application/providers/active_business_provider.dart:34`

None of them is derived from the backend `core.entity_context_sessions` / `core.user_roles` / `core.entity_members` model, and none of them is synchronized with the others. Role/permission/module gating therefore runs on **hard-coded role names and a fake role value**, while real authorization is expected to come entirely from backend RLS + security-definer RPCs.

There are **two parallel navigation/module stacks** (live `nav_config` + registry stack, and a partially wired composition/dashboard-engine stack). An Admin Dashboard must be built into the **live** stack. The `/admin` route exists but is **not role-gated and not reachable from any nav widget**.

---

## A. Current frontend identity flow

| Step | Where | Evidence |
|---|---|---|
| Supabase init | `main()` | `lib/main.dart:137-155` (`Supabase.initialize(url, anonKey)`; no `dbSchema`, so unqualified `.from/.rpc` hit `public`) |
| Client facade | `SupabaseService` singleton | `lib/core/services/supabase_service.dart:24-73`; `currentUser/currentUserId` = `client.auth.currentUser?.id` (`:39-45`) |
| Auth ops | `AuthService` via **Edge Functions only** (create-profile, select-workspaces, request-otp, verify-otp) | `lib/core/services/auth_service.dart:87`; `create-profile` header `:110-115`; `select-workspaces` `:232-375`; `verify-otp` `:455-606` |
| Session restore | `SessionController.initialize()` | `lib/core/session/session_provider.dart:61-191`; keyed by `user.id` (`:62-64`) |
| Session model | `AuthenticatedSession` (userId, displayName, selectedRoles, hasProfile, profile, workspaceIds, defaultWorkspaceId) | `lib/core/session/app_session.dart:161-228` |
| Landing decision | `resolveSessionDestination` → splash/welcome/error/createProfile/workspaceSelection/dashboard | `lib/core/session/session_destination.dart:50-70`; consumed `lib/core/session/session_gate.dart:112-170` |
| Post-auth app | `MaterialApp.router` from `appRouterProvider` | `lib/main.dart:459-476`; `lib/core/router/app_router_provider.dart:28-31` |

**Identity facts**
- `user_id` is always sourced from the live Supabase session (`SupabaseService.currentUser`) — never client-generated. Feature data queries send **no** user filter and rely on RLS; the only `.eq('auth_user_id', ...)` filters use the live auth id (`session_provider.dart:410-414,436-439`, `session_country_provider.dart:163`).
- Profiles (`users.profiles`) are selected by `auth_user_id`; the client writes nothing there directly — all writes go through Edge Functions / server RPCs.
- `selectedRoles` on `AuthenticatedSession` is **overloaded with workspace ids** (`session_provider.dart:384-386`), and `AppUser.role = selectedRoles.first` therefore returns a workspace id as "role" (`lib/core/providers/user_provider.dart:32-34`).
- `users.profiles.current_workspace_id` and `users.user_workspaces` are read by the client (`session_provider.dart:24,157-158,410-439`; `auth_service.dart:216-231`) — self-documented gap in the backend schema docs (`docs/mapping/commercial_workspace_mapping_report.md:231`).

---

## B. Current workspace/entity flow

**Domain:** `Workspace` is a runtime UI model (workspaceId, orgId, tabs, layout, history…) — `lib/core/workspace/domain/workspace_data.dart:46-247`.

- SSOT: `activeWorkspaceProvider` — `lib/core/workspace/application/active_workspace_provider.dart:327-330`; seeded from `session.defaultWorkspaceId ?? workspaceIds.first ?? 'workspace-default-001'` (`:56-79`).
- Catalog: `workspaceCatalogProvider` selects `system.workspaces` (`lib/core/workspace/domain/workspace_catalog_item.dart:49-69`; provider `lib/core/workspace/application/workspace_catalog_provider.dart:32-48`).
- Type derivation: `activeWorkspaceTypeProvider` normalizes row `category` → `farmer|trader|institution` (aliases agrovet→trader etc.) — `lib/core/workspace/application/workspace_dashboard_provider.dart:107-147`.
- Persistence: `WorkspaceStorage` implemented only by **`InMemoryWorkspaceStorage`**; provider has a `// TODO: swap to Supabase` — `lib/core/workspace/infrastructure/workspace_storage.dart:182-185`.
- Switching: shell selector → `ActiveWorkspaceNotifier.switchWorkspace` → `WorkspaceEngine.switchWorkspace`, then `context.go('/')` — `lib/core/shell/presentation/regions/shell_app_bar.dart:287-393`; `workspace_engine.dart:315-334`. **Local-only; never persists default back to `users.profiles`.** On restart the active workspace reverts to the DB default.

**Context engine (not wired to backend):**
- `contextProvider` → `EntityContext { userId, role, entityId, tier, isGuest, isLoading }` persisted to SharedPreferences — `lib/core/context_engine/providers/context_provider.dart:7-10`; `lib/core/context_engine/domain/models/entity_context.dart:1-37`; `context_storage_service.dart:4-19`.
- `ContextSyncService.fetchUserContext()` **returns a hard-coded stub** `{'userId':'server_user_id','role':'farmer','entityId':'farm_123'}` — `lib/core/context_engine/services/context_sync_service.dart:1-11`. No call to `core.entity_context_sessions` / `get_active_entity` / `set_active_entity` exists anywhere in `lib/` (only comments/docs: `docs/Backend schemas/core schema.md:378-393`).
- `switchRole/switchEntity` only write local prefs and have no callers (`context_controller.dart:57-77`). Duplicate orphan `ContextNotifier` exists (`lib/core/context_engine/controllers/context_notifier.dart`).

**Business entity:** separate `core.entities` selection — `myBusinessesProvider` → `activeBusinessIdProvider` / `activeBusinessProvider` (defaults to first) — `lib/features/business_hub/application/providers/active_business_provider.dart:34-68`; business profile is a `commerce.business_profiles` row per entity (`domain/entities/business_profile.dart:20-78`), not part of `users.profiles`.

**Farm hierarchy:** its own entityId → `selectedFarmIdProvider` (`farm_management/application/providers/farm_selector_provider.dart:107-109`) → `farmContextProvider.farmId` (`farm_context_provider.dart:59-75`).

---

## C. Current role flow

**Client role concepts (each a separate source of truth):**

| Concept | Source | Value today | Evidence |
|---|---|---|---|
| `EntityContext.role` | Context engine | `null`→guest, or **`'farmer'`** (stub) | `context_controller.dart:25-54`; `context_sync_service.dart:6-10` |
| `AppUser.role` | Session | `selectedRoles.first` = **workspace UUID** (bug) | `user_provider.dart:32-34`; `session_provider.dart:384-386` |
| `activeWorkspaceType` | Workspace | `farmer/trader/institution` | `workspace_dashboard_provider.dart:138-147` |
| `BusinessMember.roleName/roleId` | DB (correct, id-based) | `core.user_roles.id/name` | `business_hub/domain/entities/business_member.dart:19-56`; resolution `business_hub_repository_impl.dart:324-342` |
| `AccessRegistry.allowedRoles` | Static registry | `admin`, `super_admin`, farmer, buyer… | `lib/system/registry/access_registry.dart:42-176` |
| `StakeholderRole` | Onboarding UI (orphaned) | 13 roles | `lib/features/auth/presentation/pages/role_selection_screen_page.dart:45-124` |

**Hard-coded / fragile role-name checks (F):**
- `if (context.role == 'admin')` → layout preset — `lib/core/dashboard_engine/application/resolution/layout_rules.dart:46`
- role→capability preset switch on `farmer/aggregator/enterprise/cooperative…` — `lib/core/capabilities/application/capability_profile_provider.dart:89-109`
- hard-coded `'role': 'farmer'`, `'entityId': 'farm_123'` for **every** authenticated user — `context_sync_service.dart:6-10`
- `role: ctx.role ?? 'guest'` — `app_context.dart:20`; `runtime_decision_engine.dart:500`
- exact string equality widget role gates — `lib/core/feature_flags/application/services/runtime_feature_flags.dart:185-191,240-246`
- static `allowedRoles.contains(role)` route/dashboard validators — `lib/core/router/route_validation/route_safety_navigator.dart:138-149`; `lib/core/dashboard_engine/application/validation/dashboard_runtime_validator.dart:192-208`
- workspace-type role normalization (`agrovet→trader`) — `workspace_dashboard_provider.dart:107-128`; bottom nav role switch — `lib/core/navigation/shell_bottom_nav.dart:130-168`
- demo roles `'Owner'/'Sales'` — `lib/shared/demo/demo_business_hub_repository.dart:317,325`
- remote-config stub allowedRoles — `lib/core/config/remote_config/services/remote_config_service.dart:10,15`

**No `enum Role` / central role registry exists.** `lib/core/services/permission_service.dart` is 0 bytes (intended evaluator, never implemented).

---

## D. Current permission flow

**Two parallel stacks:**

**(1) Live-but-minimal:** Module visibility from `system.modules` rows + local filter flags (enabled/maintenance/premium/entity/device; **no role check**) → nav lists & router. See Section E.

**(2) Full access stack, largely dead:**
- `AccessPolicy` model (`rolePermissions`, `featureTiers`) — `lib/core/access/domain/models/access_policy.dart:1-15`
- RPC `get_access_policy` → `AccessDecisionEngine.evaluate` (rolePermissions prefix match + tier) — `lib/core/access/infrastructure/repositories/access_policy_repository.dart:13-72`; `lib/core/access/access_decision_engine.dart:22-67`
- Realtime refresh `access_policy_changes` — `lib/core/access/infrastructure/sync/access_policy_sync_service.dart:16-59` (**unwired**, table-level public-schema stream)
- `featureAccessProvider` (feature enabled + access decision + subscription) — `lib/core/feature_flags/application/providers/feature_access_provider.dart:52-77`; consumed only by unused `FeatureGate` widget — `lib/shared/widgets/gates/feature_gate_widget.dart:5-35`
- `AccessSdk` / `CapabilitySdk` facades — `lib/core/sdk/access_sdk.dart:41-141`, `lib/core/sdk/capability_sdk.dart:46-96`
- Client-side role→capability presets (stopgap, flagged TEMPORARY) — `lib/core/capabilities/application/capability_profile_provider.dart:73-109`; drives business-hub tab visibility `business_hub_page.dart:221-226`

**Membership flags** (`can_manage`, `can_sell`, `can_receive_payments`, `membership_status`) are fetched and mapped (`business_hub_remote_data_source.dart:459-472`; `business_member.dart`) but only **displayed** (`business_hub_more_tab.dart:392-398`) — no client gating.

**Permission key grammars are inconsistent (3 styles):** dot `module.action` (synthesized `runtime_decision_engine.dart:184-227`), colon `admin:view` (descriptor `PermissionDescriptor`, `lib/core/composition/domain/models/module_descriptor.dart:403-422`), underscore prefix `view_featureKey` (`feature_access_provider.dart:63-68`). No shared constant file.

**Empty scaffolds (misleading):** `lib/core/guards/auth_guard.dart`, `role_guard.dart`, `profile_guard.dart` (0 bytes); `lib/features/admin_console/domain/permissions/permissions.dart` (0 lines); `permission_service.dart` (0 bytes).

---

## E. Current module-access flow

**Module contracts (3 loosely-related):** `ModuleDefinition` (static; no role/tier fields) `lib/system/registry/registry_contracts.dart:35-87`; `FeatureDefinition` (`requiredTier`) `:96-123`; `AccessRule` (static allowedRoles) `:132-155`; runtime `ModuleRuntimeDescriptor` (contributions; no role/tier on module level) `lib/core/composition/domain/models/module_descriptor.dart:37-156`; DB DTO `SystemModule` — `lib/core/modules/domain/models/system_module.dart:1-125` — **parses keys (`premium_only`, `requires_subscription`…) that don't match backend DDL columns (`is_premium`, `required_subscription`, `required_roles`, `is_public`, `is_beta`) in `docs/Backend schemas/system_schema.md:12-31`.**

**Registered modules:** 17 static definitions `lib/system/registry/module_registry.dart:43-315`; 17 runtime descriptors `lib/core/composition/bootstrap/module_descriptor_bootstrap.dart:50-71`. System-only pages (home/search/notifications/reports/settings/ai_assistant) registered as page builders without module rows — `lib/core/composition/router/dynamic_route_registrar.dart:257-268`.

**Resolution chain actually used (Chain A):**
`ModuleService.getActiveModules()` selects `system.modules` (+ fallback public `modules`) with **5-min TTL cache** → `moduleProvider` → `runtimeModuleRegistryProvider` → `RuntimeCompositionEngine` → `ModuleAccessFilter` (enabled/maintenance/guest/premium/entity; **no role, no tier-from-backend**) → nav (`nav_config.dart`), router (`dynamic_route_registrar.dart:99-117` registers only enabled non-maintenance modules), descriptors for dashboards.

**Dead / unwired:** RPC `get_enabled_modules` (`lib/core/modules/infrastructure/repositories/module_repository.dart:7-8` → provider with zero consumers); `get_access_context` (`feature_flags/.../access_repository.dart:20`); `get_subscription_state` (`subscription_repository.dart:20`); `setTier` has **no callers** → every user evaluates as `free`; `RemoteConfigService` returns hardcoded dummy config (`remote_config_service.dart:3-18`).

**Realtime:** `RuntimeSyncEngine` (module_runtime_sync) watches `system.modules` + `system.module_installations` (`runtime_sync_engine.dart:436-471`) but **does not invalidate `ModuleService`'s 5-min cache** — admin toggles surface only after TTL/restart (`module_service.dart:44-152`; no caller of `refreshModules()`).

---

## F. Current navigation/dashboard flow

**Entry/landing:** `SessionGate` → authenticated → GoRouter (`initialLocation: '/'`) — `lib/core/composition/router/dynamic_route_registrar.dart:130-136`; `/` → `UnifiedDashboardHost`.

**`UnifiedDashboardHost` dispatches `/` directly to the workspace primary module** (no dashboard card):
- farmer → `FarmManagementPage`, trader/supplier → `BusinessHubPage`, institution → `FinancingPage`; unmapped → `ResponsiveDashboardRenderer` — `lib/core/shell/presentation/regions/unified_dashboard_host.dart:33-54`.

**Shell:** `UnifiedAppShellV2` (breakpoint layouts) — `lib/core/shell/presentation/pages/new_unified_app_shell.dart:87-242`. Nav surfaces:
- Sidebar: static "Dashboard" item + `sidebarNavItemsProvider` — `lib/core/navigation/shell_sidebar.dart:50-69`
- Bottom nav (mobile): **fixed 5-slot skeleton** (Home `/home`, Marketplace, workspace dashboard item-3, Traceability, More sheet) — `lib/core/navigation/shell_bottom_nav.dart:56-169`
- Nav items from `nav_config.dart` providers (`:86-181`), governance-filtered then **workspace-scoped** to `_workspaceAgnosticModuleKeys` + per-type promotions (`:56-90`).

**Does workspace switching change nav/dashboard? Yes.** Selector → `switchWorkspace` → recompute `activeWorkspaceTypeProvider` → nav re-scope + `/` landing swap + bottom-nav item-3 label (`shell_app_bar.dart:384-391`; `workspace_dashboard_provider.dart:138-189`; `unified_dashboard_host.dart:40-48`). Local-only (not persisted as backend default).

**Does role/permission change nav? No.** Nav governance checks module flags + workspace scope only; role gates widgets/sections (`runtime_feature_flags.dart:185-191,240-246`) which aren't wired to nav items. `FeatureGate` unused in nav. `RouteSafetyNavigator` (only role-checking route helper) has **zero callers**.

**Dashboard content flow:** module page watches `moduleWidgetDescriptorsProvider('farm_management')` → descriptor chain → `WidgetRegistry.resolve` → registered widgets (`farm_management_page.dart:583-604,665-683`; `widget_registry.dart:115-137`). Registration via per-feature `*_widget_registration_bootstrap.dart` from `bootstrapPhaseD()` (`main.dart:278`). The `dashboard_engine` pipeline/renderers are mostly an observability layer, not on the normal `/` path.

**Admin route:** `/admin` → `AdminDashboardPage` registered only if an enabled `admin_console` `system.modules` row exists (`dynamic_route_registrar.dart:252`, `:99-117`). **Not reachable from any nav widget** (`admin_console` not in `_workspaceAgnosticModuleKeys` nor any promotion map) and **not role-gated** (static blueprint `isEnabledDefault:false, isVisibleDefault:false`, `module_registry.dart:295-297`).

---

## G. Client-side authorization / security risks

1. **Client-supplied entity/farm/asset scoping assumed RLS-safe.** `entity_id`, `farm_id`, `seller_id`, `asset_id` filters originate from client-selected state (not `auth.uid()`):
   - entity_id: `business_hub_remote_data_source.dart:129,152,288,365,469`; `marketplace_remote_data_source.dart:330,373,529`; `supabase_spatial_repository.dart:61,104`
   - created_by/profile_id/supplier_id in-filter chains: `business_hub_remote_data_source.dart:316,393,524`; `business_hub_repository_impl.dart:56-60`
   - farm_id pervasive: `farm_repository_impl.dart:175,208,271,604,736,1028,1254,1338,1386,1409`; `kpi_automation_service.dart:164,220,244,280`; `stock_mutation_engine.dart:83,183,276`
   If any RLS policy trusts the client filter instead of re-verifying membership/ownership, cross-org enumeration follows.
2. **Fetch-broad-then-filter-in-Dart:** all `activities` downloaded and filtered by farm in Dart — `farm_repository_impl.dart:1272-1285`; all listings scanned for stock_id — `marketplace_repository_impl.dart:548-560`; eligible-stock computed client-side `:379-393`.
3. **Wide-open / no-predicate reads:** `widget_states` global load/save with no user scope — `lib/core/dashboard_engine/infrastructure/repositories/widget_hydration_repository.dart:12-28`; `modules` fallback (public) — `module_service.dart:99`; `system.modules`/`system.workspaces` select-all (catalog, low sensitivity); `access_policy_changes` table-level realtime stream — `access_policy_sync_service.dart:17-19`.
4. **Schema drift:** spatial tables documented as `spatial.*` but queried **unqualified** (default/public) — `supabase_spatial_repository.dart:59-270`; legacy `MarketplaceService` and `ModuleService` fallback hit public `listings`/`modules`; RPCs inconsistent (core governance unqualified; farm/marketplace RPCs schema-qualified).
5. **Client-side gate bypass risk:** role/tier/module gates are evaluated client-side from RPC/local state; real protection must be backend RLS + security-definer RPCs. If backend is weak, direct API access bypasses everything.
6. **`entity_context_sessions` never used:** the intended context table (`active_mode`, `active_role_id`, `business_profile_id`, `session_status`, `is_default`) is never read/written by the app; role gating instead uses a stub (`context_sync_service.dart`) or role-name strings.
7. **Admin write RPCs unguarded client-side:** `update_feature_flag`/`toggle_module`/`update_role_permission`/`update_feature_tier` called with no client guard — `admin_governance_service.dart:6-41`. Protection depends entirely on backend.

---

## H. Hard-coded role/permission logic

See Section C table and D. Highlights of the fragile entries:
- role-name strings duplicated in ≥10 files (no central registry): `access_registry.dart`, `capability_profile_provider.dart`, `layout_rules.dart`, `remote_config_service.dart`, `workspace_dashboard_provider.dart`, `shell_bottom_nav.dart`, `demo_business_hub_repository.dart`, `context_sync_service.dart`, `runtime_feature_flags.dart`, `route_safety_navigator.dart`, `dashboard_runtime_validator.dart`.
- Tier strings duplicated: `free/basic/premium/enterprise` in `subscription_tier.dart`, `feature_registry.dart`, `runtime_feature_flags.dart:121,195`, `module_access_filter.dart:105,113`, tier-order arrays `dashboard_runtime_validator.dart:214`, `route_safety_navigator.dart:161`.
- `AppUser.role = selectedRoles.first` (workspace UUID as role) — `user_provider.dart:32-34`.

---

## I. Duplicate / legacy frontend architecture

1. **Two module fetchers:** `ModuleService` (system.modules select + cache; used) vs `ModuleRepository` (`get_enabled_modules` RPC; unused) — `module_service.dart:55-58` vs `core/modules/infrastructure/repositories/module_repository.dart:7-8`.
2. **Three "current role" holders that disagree:** `EntityContext.role` (≈`'farmer'` stub), `AppUser.role` (≈workspace UUID), `activeWorkspaceType` (category).
3. **Two nav stacks:** live `nav_config.dart` + registry-driven router (`DynamicRouteRegistrar`) vs partially wired `composition_providers.dart` / `dashboard_engine` pipeline / `CompositionNavBuilder` (its `CompositionNavItem`s are **not consumed** by any shell widget).
4. **Orphaned/legacy:** `lib/core/services/marketplace_service.dart` (`@Deprecated`, public-schema `listings`); `lib/app/app.dart` empty; `lib/core/router/app_router.dart` deprecated shim (`:54-64`); `HomePage` (`features/home`) not routed (the `/home` destination shows `FamhubHomePage` from `features/guest`); `FarmHomePage` alternate landing not referenced by module registry; `RoleSelectionScreenPage` 13-role onboarding unwired; `AuthProvider` Hive `auth_cache` orphan; `ContextNotifier` duplicate controller; two `moduleAccessProvider`s (`governance_provider.dart:91` vs `composition_providers.dart:199`); two `module_access_filter`-style filters.
5. **Realtime sync not applied:** `RuntimeSyncEngine` writes `ModuleRuntimeState` consumed only by status icon + validator; never invalidates the module cache.
6. **Dead static catalogs:** `FeatureRegistry`, `AccessRegistry`, `DependencyRegistry`, `RemoteConfigService`, feature_flags repos, `SubscriptionRepository` — largely unused and able to drift from runtime/backend.

---

## J. Backend RPC dependencies (all frontend invocations)

**Authorization / context functions referenced by the brief:** NONE of `core.auth_user_id()`, `core.has_permission()`, `core.get_active_entity()`, `core.set_active_entity()`, `core.ensure_entity_for_profile()`, `commerce.add_owner_entity_role()`, `commerce.accept_entity_invitation()`, `commerce.is_entity_manager()`, `commerce.deactivate_entity_role()`, `users.save_user_workspaces()` are invoked from Dart. `save_user_workspaces`-equivalent is done via the **`select-workspaces` Edge Function** (`auth_service.dart:232-375`); entity creation goes through **`create_farm_with_auto_entity`** (`farm_repository_impl.dart:48-61`). The context/RBAC RPCs exist only in docs/comments.

**RPCs actually invoked:**

| RPC | Caller (file:line) | Params | Schema ctx |
|---|---|---|---|
| `get_access_policy` | `core/access/.../access_policy_repository.dart:15-17`; `.../sync/access_policy_sync_service.dart:26` | none | default |
| `get_access_context` | `core/feature_flags/.../access_repository.dart:20` | none | default (dead) |
| `get_subscription_state` | `core/feature_flags/.../subscription_repository.dart:20` | none | default (dead) |
| `get_enabled_modules` | `core/modules/.../module_repository.dart:7-8` | none | default (dead) |
| `get_effective_policy` | `core/policies/.../supabase_policy_repository.dart:51-57` | p_organization_id, p_location_id | default |
| `detect_spatial_overlaps` | `core/spatial/.../supabase_spatial_repository.dart:284-287` | target_asset_id | default (spatial schema not qualified) |
| `update_feature_flag` | `features/admin_console/.../admin_governance_service.dart:7-10` | feature_key, enabled | default |
| `toggle_module` | same `:17-20` | module_key, enabled | default |
| `update_role_permission` | same `:27-30` | role, permission | default |
| `update_feature_tier` | same `:37-40` | feature_key, tier | default |
| `create_farm_with_auto_entity` | `farm_management/.../farm_repository_impl.dart:48-61` | farm_data{...} | commerce |
| `create_crop_livestock_asset` | same `:482-491` | asset_data{...} | farm_management |
| `create_production_record` | same `:784-786` | p_production_data{...} | farm_management |
| `create_activity` | same `:1148-1150` | activity_data{...} | farm_management |
| `fn_aggregate_production_kpis` | `kpi_automation_service.dart:64-67` | p_farm_id | default |
| `fn_aggregate_financial_kpis` | same `:110-113` | p_farm_id | default |
| `publish_listing_from_stock` | `marketplace_remote_data_source.dart:296-298` | p_stock_id, p_price_per_unit, p_title, p_description, p_images | marketplace |
| `update_listing` | same `:572-580` | p_listing_id, p_changes | marketplace |
| `set_listing_status` | same `:592-597` | p_listing_id, p_status | marketplace |

**Edge Functions:** `create-profile`, `select-workspaces`, `request-otp`, `verify-otp` (`auth_service.dart`); `upload_media`, `media_get_by_context`, `delete_media` (marketplace).

**Realtime:** `system.modules`/`system.module_installations` channel (module_runtime_sync); `access_policy_changes` stream (unwired).

**Schemas referenced in Dart:** `system` (modules, workspaces), `core` (entities, entity_members, user_roles, items, item_variants, units, locations, domains, categories, commodities, countries, geography_levels), `users` (profiles, user_workspaces), `farm_management` (farms, fields, assets, plans, activities, activity_types, activity_attribute_rules, activity_workflow, activity_values, production_records, financial_records, farm_reports, farm_kpis, farm_aggregates, activity_stock_rules), `commerce` (business_profiles, stock_registry, purchase_orders, orders, order_items, transactions), `marketplace` (listings + 3 RPCs). `spatial.*` documented but unqualified in code. Default `public` implied for all unqualified calls.

---

## K. Files/classes/providers/services affected

**Core live identity/session:** `lib/main.dart`; `lib/core/services/supabase_service.dart`; `auth_service.dart`; `lib/core/session/{session_provider, session_gate, session_destination, app_session}.dart`; `providers/session_country_provider.dart`; `lib/core/providers/user_provider.dart`.

**Workspace/context:** `lib/core/workspace/{application/{active_workspace_provider, workspace_catalog_provider, workspace_dashboard_provider, workspace_engine}, domain/*, infrastructure/workspace_storage.dart, composition/workspace_bridge.dart}`; `lib/core/context_engine/**`.

**Roles/permissions/access:** `lib/core/access/**`; `lib/core/policies/**`; `lib/core/capabilities/**`; `lib/core/guards/*`; `lib/core/services/permission_service.dart`; `lib/system/registry/{access_registry, feature_registry, dependency_registry, module_registry, route_registry, registry_contracts}.dart`; `lib/shared/widgets/gates/feature_gate_widget.dart`; `business_hub/domain/entities/business_member.dart` + `members_provider.dart`.

**Modules/feature flags/subscription:** `lib/core/modules/**`; `lib/core/feature_flags/**`; `lib/core/subscription/**`; `lib/core/config/remote_config/**`; `lib/core/module_runtime_sync/**`; `lib/core/services/module_service.dart`; `lib/core/providers/module_provider.dart`; `admin_console/**` (page, `admin_governance_service.dart`, permission tiles).

**Composition/router/nav:** `lib/core/router/**`; `lib/core/composition/**` (router/dynamic_route_registrar, providers, domain/models/module_descriptor, engine/*); `lib/core/navigation/**`; `lib/core/shell/**`; `lib/core/dashboard_engine/**`; `lib/core/runtime_decision/**`.

**Feature consumers (per role type for module-landing mapping):** `farm_management`, `business_hub` (+ `trader` descriptor), `financing`, `marketplace`, `analytics`, `logistics`, `traceability`, `carbon_credit`, `knowledge_link`, `extension_services`, `opportunities`, `agri_connect`, `agri_tech_lab`, `refferal_hub`, `profile`, `guest`, `home`, `search`, `notifications`, `reports`, `settings`.

**Query-heavy data files:** `farm_management/.../farm_repository_impl.dart` (~17 tables/43 ops + 4 RPCs), `marketplace_remote_data_source.dart` (7 tables + 3 RPCs), `business_hub_remote_data_source.dart` (14 tables), `core/spatial/.../supabase_spatial_repository.dart`, `kpi_automation_service.dart`, `stock_mutation_engine.dart`.

---

## L. Recommended migration sequence (no changes made)

**Phase 0 — freeze & gate (before any code):**
1. Ship backend context/RBAC (as per the completed database architecture audit) with correct RLS first.
2. Add real role gating on backend before exposing Admin.

**Phase 1 — single source of truth for context:**
3. Replace `ContextSyncService` stub with a real fetch wired to `core.entity_context_sessions` / active-entity RPC (`get_access_context` already exists as an unwired RPC client). Persist `active_role_id`/`active_mode`/`business_profile_id` client-side from backend response.
4. Reconcile `selectedRoles` misuse: stop overloading with workspace ids; derive `AppUser.role` from context, not `selectedRoles.first`.

**Phase 2 — module/access data-driven:**
5. Wire `get_enabled_modules`/`get_subscription_state`/`get_access_policy` (repos already written, zero consumers) into `moduleProvider` + nav so module visibility is role/tier-scoped and backend-controlled.
6. Fix `SystemModule.fromMap` to backend DDL keys; make realtime sync invalidate `ModuleService` cache so admin toggles apply immediately.

**Phase 3 — single navigation stack:**
7. Retire/deprecate the parallel composition-provider nav; keep `nav_config` + `DynamicRouteRegistrar` as the one live path; delete dead catalogs and 0-byte guard files.

**Phase 4 — Admin Dashboard (only after Phases 1-3):**
8. Register admin as a data-driven, role-gated module: backend `system.module_access_rules` entry + role, enable via `system.modules`, client role-gate at route (`RouteSafetyNavigator` or a real guard) and nav item (workspace-agnostic + role check).
9. Model the Admin landing page on `UnifiedDashboardHost` dispatch + `WidgetRegistry` contribution pattern; register admin widgets via `bootstrapPhaseD`.

**Phase 5 — hardening:**
10. Centralize role/permission constants (single typed enum + constant file) and delete role-name string comparisons; centralize tiers.
11. Audit Type-B/C/D data access (Section G): push tenant-scoping and eligibility computations into RPCs/views; schema-qualify spatial & widget_states.

---

## M. Critical findings that must be fixed before Admin Dashboard

1. **No real "current role" exists client-side.** Role gating runs on `EntityContext.role`, which is hard-coded to `'farmer'` by `ContextSyncService` (`context_sync_service.dart:6-10`). Every user would look like a farmer to an Admin Dashboard gate. Must wire real context (Phase 1) first.
2. **Admin is not reachable in nav and not role-gated.** `/admin` route exists only when a global `system.modules` row is enabled (`dynamic_route_registrar.dart:99-117,252`); `admin_console` appears in no nav list (`nav_config.dart:56-90`); the only role check (`access_registry.dart:44-53`) feeds the unused `RouteSafetyNavigator`; `AdminDashboardPage` and `admin_governance_service.dart` perform **no authorization**. Any user reaching `/admin` could call the four admin RPCs.
3. **Client-side gates are bypassable; backend must enforce.** Data queries pass client-supplied `entity_id`/`farm_id`/`seller_id` and assume RLS re-verifies (Section G). Admin actions need security-definer RPCs + RLS, not client checks.
4. **`entity_context_sessions`/`user_roles`/`entity_members` backend model is unused by the app.** Role names/ids come from string constants and a stub; `BusinessMember.roleId/roleName` (id-based, correct) is display-only. Before Admin, adopt the DB role model app-wide.
5. **Multiple conflicting context singletons.** Active workspace (system.workspaces type), EntityContext (stub role), ActiveBusiness (core.entities), farm hierarchy entityId, and session.selectedRoles (workspace ids) all disagree. Admin context switching (super-admin across orgs/businesses) is impossible until these converge.
6. **Tier/subscription is effectively `free` for everyone.** `get_subscription_state` repo + `setTier` have no consumers; any enterprise-gated Admin content would never pass client checks. Decide: enforce tier server-side and remove client tier-gating, or wire subscription state.
7. **Dead 0-byte guards (`core/guards/*`) and unused `FeatureGate`/`RouteSafetyNavigator` give a false sense of protection.** Do not extend them; build gating into the live router/nav path with a real guard.
8. **Schema drift risks breaking the module engine.** `SystemModule.fromMap` expects keys that don't exist in backend DDL (`system_schema.md:12-31`); spatial and widget_states query the wrong schema. Fix before Admin depends on module metadata.
9. **Admin UI will land on the wrong stack if added to composition providers.** The live stack is `nav_config` + `DynamicRouteRegistrar` + `UnifiedDashboardHost`/`WidgetRegistry`. Adding to `composition_providers`/`dashboard_engine` only will have no visible effect.
10. **Realtime module toggles are not applied** (5-min cache TTL; `refreshModules()` has no callers). Until fixed, disabling a module via Admin will not visibly hide it for minutes.

---

*Report produced from a read-only audit of `/data/data/com.termux/files/home/projects/Famhub-web`. Companion: database architecture audit. No files were modified.*
