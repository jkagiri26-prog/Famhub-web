# FAMHUB Admin Authorization Verification (Real Admin Context)

**Type:** Piece-work verification — existing frontend authorization/context pipeline for Admin.
**Date:** 2026-09-12
**Repo:** `Famhub-web` (Flutter, supabase_flutter, Riverpod, go_router)
**Canonical Admin context (per brief):**
- Workspace: Administration
- Entity: Platform Administration `01a091e6-f283-70b5-9393-813acf541c09`
- Role: Admin `60773165-412a-4d1b-98da-5c9f2e7fe307`
- Backend: 23 `admin.*` global permissions, 17 `entity.*` permissions, 1 Admin global scope, 1 Admin entity scope (Platform Administration), 0 overrides.

**Constraints honored:** no backend/schema/RLS/migration/permission/role changes; no new provider/registry/context system; no client-side grants; no hardcoded Admin permissions.

---

## 1. Files inspected

**Session / identity**
- `lib/core/session/session_provider.dart` (profile + workspace restore, `selectWorkspaces` folds backend context)
- `lib/core/session/session_gate.dart`, `lib/core/session/session_destination.dart`

**Workspace / context**
- `lib/core/shell/presentation/regions/shell_app_bar.dart` (workspace switch + `_resolveAndActivateContext`)
- `lib/features/workspace_context/application/entity_context_refresh.dart` (post-switch refresh)
- `lib/core/workspace/application/{active_workspace_provider,workspace_dashboard_provider,workspace_catalog_provider}.dart`
- `lib/core/context_engine/services/context_sync_service.dart`
- `lib/core/context_engine/controllers/context_controller.dart`
- `lib/core/context_engine/domain/models/{entity_context,app_context}.dart`
- `lib/core/services/auth_service.dart` (`get_available_workspace_contexts`, `activate_workspace_context`, `complete_workspace_selection`, `add_workspace_membership`)

**Authorization**
- `lib/core/access/infrastructure/repositories/access_policy_repository.dart` (`get_access_policy`)
- `lib/core/access/application/providers/access_policy_provider.dart`
- `lib/core/access/access_decision_engine.dart`
- `lib/core/access/domain/models/access_policy.dart`
- `lib/core/runtime_decision/application/{runtime_decision_provider,runtime_decision_engine}.dart`
- `lib/core/organization_runtime/application/active_organization_provider.dart` (the only existing invalidator)

**Admin**
- `lib/features/admin_console/application/providers/admin_capability_provider.dart`
- `lib/features/admin_console/domain/models/admin_capability.dart`
- `lib/features/admin_console/domain/permissions/permissions.dart`
- `lib/features/admin_console/presentation/pages/admin_dashboard_page.dart`
- `lib/features/admin_console/infrastructure/services/admin_governance_service.dart`

**Navigation / routing**
- `lib/core/navigation/nav_config.dart`
- `lib/core/shell/presentation/regions/unified_dashboard_host.dart`
- `lib/core/composition/router/dynamic_route_registrar.dart`

**Backend reference**
- `docs/Backend schemas/core schema.md` (`entity_context_sessions.active_mode`, `role_permissions`, `entity_role_scopes`, `permission_overrides`)
- `docs/mapping/commercial_workspace_mapping_report.md`

---

## 2. Code changed

**One file, minimal invalidation fix only:**

`lib/features/workspace_context/application/entity_context_refresh.dart`
- Added `import ...core/access/application/providers/access_policy_provider.dart;`
- Added `ref.invalidate(accessPolicyProvider);` to `refreshEntityScopedProviders()`.
- Updated the function doc comment.

No other Dart, SQL, schema, RLS, permission, role, or navigation changes.

---

## 3. Existing flow trace (auth → admin dashboard)

```
Supabase auth (auth.users.id)                          auth_service.dart / supabase_service.dart
  → users.profiles (by auth_user_id)                   context_sync_service.dart:31-35
  → users.user_workspaces → workspace ids              session_provider.dart:434-451
  → activeWorkspaceProvider (workspace id)             active_workspace_provider.dart:56
  → activeWorkspaceTypeProvider (category→type)        workspace_dashboard_provider.dart:163-172
  → '/' → UnifiedDashboardHost → primary module        unified_dashboard_host.dart:40-49
        admin type → 'admin_console' → AdminDashboardPage
  → AdminDashboardPage                                 admin_dashboard_page.dart:43
       watches adminDashboardAccessProvider
         → adminWorkspaceAccessProvider (base gate)    admin_capability_provider.dart:80-109
              requires: not loading, not guest, context.role non-empty, access policy loaded
         → adminCapabilityStatusProvider(permissionKey) admin_capability_provider.dart:118-141
              → runtimeDecisionProvider(RuntimeRequest(action:'view', module:'admin_console',
                                                       permission: <AdminPermissions.*>))
                → runtimeDecisionEngineProvider            runtime_decision_provider.dart:63-92
                     watches contextProvider + accessPolicyProvider
                     → AccessDecisionEngine.evaluate(permission, role: context.role, tier)
                        → policy.rolePermissions[role]         access_decision_engine.dart:39
                        → permission.startsWith(granted)        access_decision_engine.dart:41-43

Workspace/entity switch:
  shell_app_bar: switchWorkspace → _resolveAndActivateContext
    → users.get_available_workspace_contexts()
    → users.activate_workspace_context(p_workspace_id, p_entity_id, p_role_id, p_business_profile_id)
    → contextProvider.applySelectionContext(entityId, roleId, role=active_mode, businessProfileId)
    → refreshEntityScopedProviders(ref)                shell_app_bar.dart:570-592
```

**Key facts confirmed:**
- The active role used by the access engine is `EntityContext.role`, which is populated from `core.entity_context_sessions.active_mode` (`context_controller.dart:60-70`, `context_sync_service.dart:68`). For Admin this is `'admin'`.
- The Admin capability provider consumes the **existing** authorization result; it contains no grants. It renders a capability only when `RuntimeDecisionEngine` → `AccessDecisionEngine` explicitly allows the permission (`admin_capability_provider.dart:187-201`).
- Authorization does **not** key off workspace key, role name, entity name, or module visibility. The base gate only checks context/role presence + policy availability (`admin_capability_provider.dart:80-109`); the per-capability gate is the access policy.
- The frontend never invokes `core.has_permission()` directly. The authoritative client path is `get_access_policy` → `AccessDecisionEngine` (which the backend composes from `core.role_permissions`/`entity_role_scopes`/`permission_overrides`). No bypass was introduced.

---

## 4. Verification results (brief items 1–9)

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Switch Farmer → Administration workspace | **Wired (not interactively testable here)** | `shell_app_bar.dart:454-470`, `_resolveAndActivateContext` 481-597 |
| 2 | Entity resolves to Platform Administration | **Wired; live value not verifiable offline** | entity id from `activate_workspace_context` → `applySelectionContext` (`shell_app_bar.dart:540-581`) |
| 3 | Active role resolves to Admin | **Wired; role passed as `active_mode`** (`'admin'`), **not** the role UUID | `context_controller.dart:98`, `context_sync_service.dart:68`; `access_decision_engine.dart:39` |
| 4 | Access-policy pipeline receives Administration context | **Partially** — context reaches the engine, but the policy itself was **not refetched** on switch (see §5) | `runtime_decision_provider.dart:68-70`; `active_organization_provider.dart:174` only |
| 5 | Admin provider uses existing authorization result (no hardcoded grants) | **Yes** | `admin_capability_provider.dart:118-141,177-207` |
| 6 | Representative permission resolution | **Not interactively testable**; static contract comparison in §6 | `admin_capability.dart`, `permissions.dart` |
| 7 | Allowed only because Admin scope granted | **By construction yes** (no client grants) | `admin_capability_provider.dart` header + `access_decision_engine.dart` |
| 8 | Switch back to Farmer | **Wired** | same switch path |
| 9 | Admin capabilities no longer presented after switch | **Depends on policy refetch — was broken before fix; addressed by §5** | `refreshEntityScopedProviders` now invalidates `accessPolicyProvider` |

---

## 5. Cache / invalidation analysis (the defect found)

**Was invalidation already correct? No.**

- `accessPolicyProvider` is a **non-autoDispose `FutureProvider`** that calls `get_access_policy` with **no parameters** (`access_policy_provider.dart:12-17`, `access_policy_repository.dart:13-17`). The backend derives the result from the **active `core.entity_context_sessions` row**, so the policy is entity/role-scoped.
- The **only** invalidation of `accessPolicyProvider` is in `ActiveOrganizationNotifier._triggerRuntimeRefresh` (`active_organization_provider.dart:174`).
- `ActiveOrganizationNotifier.init()`/`refresh()`/`switchOrganization()` are **never called** on app start or on workspace/entity switch (only `organization_sdk.dart:70,76`; no `main.dart` init).
- The workspace/entity switch path (`shell_app_bar._resolveAndActivateContext`) calls only `contextProvider.applySelectionContext(...)` + `refreshEntityScopedProviders(ref)`. Before this fix, `refreshEntityScopedProviders` invalidated only Business Hub, Marketplace seller, and Farm providers — **not** `accessPolicyProvider`.

**Consequences:**
- Switching **into** Administration: `contextProvider` updates, but `AccessDecisionEngine` keeps the previously cached (farmer) policy → Admin permissions do not resolve even though the context is correct.
- Switching **back** to Farmer: the Admin policy could remain cached → **stale Admin authorization**, exactly the risk the brief calls out.

**Minimal fix applied** (no new provider, no architecture change): invalidate the existing `accessPolicyProvider` in the existing post-switch refresh hook. `runtimeDecisionEngineProvider` and the Admin capability providers already watch it, so they refresh automatically.

---

## 6. Permission contract comparison (static)

The Admin capability provider requests the permission keys defined in `AdminPermissions` (`permissions.dart`). The backend codes named in the brief are compared below. **Resolution is by `requestedPermission.startsWith(grantedCode)`** (`access_decision_engine.dart:41-43`), so a mismatch resolves to **denied** unless the backend also grants a broader prefix.

| Descriptor | Frontend key requested (`permissions.dart`) | Brief's backend code | Exact match? |
|---|---|---|---|
| platform_overview | `admin.view` | `admin.overview` | **No** |
| platform_users | `admin.users.manage` | `admin.users.view` | **No** |
| platform_organisations | `admin.organisations.manage` | `admin.entities.view` | **No** |
| platform_modules | `admin.modules.manage` | `admin.modules.view` | **No** |
| platform_audit | `admin.audit.view` | `admin.audit.view` | **Yes** |
| entity_overview | `entity.view` | `entity.overview.view` | **No** |
| entity_members | `entity.members.manage` | `entity.members.view` | **No** |
| entity_roles | `entity.roles.manage` | `entity.roles.view` | **No** |
| entity_module_access | `entity.module_access.manage` | `entity.module_access.view` | **No** |
| entity_audit_trail | `entity.audit.view` | `entity.audit.view` | **Yes** |

**Cannot verify offline:** the actual `role_permissions` payload returned by `get_access_policy` (role-key naming, exact granted codes, and whether the Admin role is granted broad prefixes). This requires the live authenticated Admin session. If the backend grants granular codes as listed above, **8 of the 10 representative capabilities will resolve as denied** due to the key mismatch. If the backend grants module-level prefixes (e.g. `admin`, `entity`), all `admin.*`/`entity.*` requests would pass via `startsWith`.

**Recommendation (not applied — needs backend confirmation):** reconcile `AdminPermissions` constants with the backend `core.permissions.code` values. This is a contract-identifier correction, not a grant, but it was not changed here because only the representative subset was provided and guessing the remaining 13 platform / 7 entity codes could silently hide or expose capabilities.

---

## 7. flutter analyze

- **Changed file:** `flutter analyze lib/features/workspace_context/application/entity_context_refresh.dart` → **No issues found.**
- **Project:** `flutter analyze` → **94 issues found** (pre-existing `info`/`warning` lints: unused locals/elements, `prefer_const_constructors`). None are in the changed file.

---

## 8. What could and could not be verified

**Statically verified**
- The complete existing flow from auth → profile → workspace → active entity → active role → access policy → Admin capability visibility.
- Admin capability provider consumes the existing authorization result and grants nothing.
- No authorization inference from workspace key / role name / entity name / module visibility.
- The invalidation defect and the minimal fix.

**Not verifiable in this environment (no interactive authentication / device)**
- Live `get_access_policy` output for the Admin context (role key naming and granted codes).
- Whether the 10 representative permissions resolve `allowed` at runtime.
- The actual `active_mode`/`role_id`/`entity_id` values returned by `activate_workspace_context` for Platform Administration.

No results were fabricated. A live run of the authenticated flow (switch to Administration, open `/`, inspect the Admin capability list and the `[WorkspaceSwitch]` diagnostics) is required to close items 2, 3, 6, 7 and 9.

---

## 9. Summary

- **Code changed:** yes — one minimal invalidation line in `entity_context_refresh.dart`.
- **Invalidation was already correct?** No — `accessPolicyProvider` was never invalidated on context switch; fixed.
- **Admin provider hardcodes grants?** No.
- **Bypasses `core.has_permission()`?** No new bypass; existing path is `get_access_policy` → `AccessDecisionEngine`.
- **Blocking risk to confirm:** frontend `AdminPermissions` keys vs backend codes mismatch on 8/10 representative permissions (pending live `get_access_policy` payload).
- **Analyze:** changed file clean; project has 94 pre-existing lint issues.
- **No new Admin features were started.**
