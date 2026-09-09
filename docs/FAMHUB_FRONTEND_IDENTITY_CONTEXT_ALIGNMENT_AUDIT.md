# FAMHUB Frontend Identity & Context Alignment Audit

**HEAD audited:** `d0229d9` · Read-only audit · No code or data changes were made.

## Canonical identity chain (target)

```
auth.uid()
 ↓
users.profiles.auth_user_id
 ↓
users.profiles.id
 ↓
core.entities.id
 ↓
active entity role
 ↓
permissions
 ↓
module/workspace access
 ↓
data queries
 ↓
dashboard/navigation
```

## Master table

| Area | Current ID used | Correct ID | Status | File |
|---|---|---|---|---|
| Profile load | `.eq('auth_user_id', userId)` (auth.users.id) → profile row | Auth id to look up `users.profiles` — correct | ✅ | `lib/core/session/session_provider.dart:413,439` |
| Context engine "entityId" | Fabricated `'farm_123'`; role `'farmer'`; userId `'server_user_id'` | `core.entities.id` / real profile | ❌ WRONG | `lib/core/context_engine/services/context_sync_service.dart:9-16`, `context_controller.dart:20-60` |
| Farm list (`getUserFarms`) | No identity filter — `farms.select().eq('is_active',true)`, RLS-only | None passed (RLS), but no client entity linkage exists | ⚠️ | `farm_repository_impl.dart:245-258` |
| Farm entity linkage | `create_farm_with_auto_entity` RPC returns `entity_id` — discarded (`(farmId, _)`) | Should be retained as active entity | ❌ | `farm_repository_impl.dart:108` |
| FarmEntity model | `id` = `farm_management.farms.id` only; no `entity_id`/`owner_id` | Carry `core.entities.id` | ⚠️ | `lib/features/farm_management/domain/entities/farm_entity.dart` |
| Fields | `.eq('farm_id', farmId)` | Farm-scoped — correct given farm list | ✅ | `farm_repository_impl.dart:267` |
| Assets / Activities / Production / Financial | `.eq('farm_id', farmId)`; activities via asset/plan `.or()`; farm-scoped | Farm-scoped — correct given farm list | ✅ | `farm_repository_impl.dart:600,653,734,1026,1250,1357,1432` |
| Marketplace browse | Global `listings.select()` RLS-scoped | Shared marketplace — acceptable | ✅ | `marketplace_remote_data_source.dart:308-343` |
| Marketplace "by seller" | `.eq('entity_id', sellerId)`; sellerId = `listing.entityId` (data-driven) | `core.entities.id` — correct | ✅ | `marketplace_remote_data_source.dart:330`, `product_details_page.dart:246-251` |
| Marketplace create listing | `entity_id` from a free-text field; empty → `null` | Active `core.entities.id` (auto) | ❌ WRONG | `listing_form_widget.dart:26,44,94-96,224` |
| Seller profile lookup | `business_profiles.eq('entity_id', entityId)` (2-hop) | `core.entities.id` — correct | ✅ | `marketplace_remote_data_source.dart:365-377` |
| Business Hub my-entities | `core.entities` RLS-scoped `select()` | RLS → correct pattern | ✅ | `business_hub_remote_data_source.dart:104-120` |
| Business inventory/listings/members | `.eq('entity_id', activeBusiness.id)` | `core.entities.id` — correct | ✅ | `business_hub_remote_data_source.dart:129,152,288,365,469` |
| Business "owner id" | `entities.owner_id` read; comments disagree (auth uid vs profile id) | Unify owner_id vs entity_members.profile_id domains | ⚠️ AMBIGUOUS | `business_hub_remote_data_source.dart:265-275` |
| Workspace | `activeWorkspaceProvider.workspaceId` = `system.workspaces.id` | Workspace id (not an entity id) — correct separation | ✅ | `active_workspace_provider.dart:327` |
| Dashboard destination | Dispatches by `activeWorkspaceType` → module landing | Workspace-following page — correct | ✅ | `unified_dashboard_host.dart:33-45` |
| Farm demo/live switch | `farmRepositoryProvider` keyed on `isAuthenticatedProvider` | Auth flip → reactive swap — correct | ✅ | `farm_repository_provider.dart:22-31` |
| Marketplace/Business demo/live | Same `isAuthenticatedProvider` keying | Auth flip → reactive swap — correct | ✅ | `business_hub_repository_provider.dart:27` |

## 1. Confirmed identity mismatches

1. **Context engine fabricates identity** — `ContextSyncService.fetchUserContext()` returns hardcoded `userId: 'server_user_id'`, `entityId: 'farm_123'`, `role: 'farmer'` (`context_sync_service.dart:9-16`). `ContextController.init()` persists it (`context_controller.dart:34-51`). It leaks into `farmContextProvider.role` (`farm_context_provider.dart:60`) → every farm context reports role `'farmer'` regardless of the real entity/role.
2. **Listing creation has no owner** — `listing_form_widget.dart:94-96` sends `entity_id: null` unless a user manually types the UUID into a raw text field (`:224`, hint "UUID of core.entities"). New listings are created with **no entity owner**; under entity-keyed RLS they will not appear in the owner's marketplace. Most probable cause of "new marketplace listings don't show."
3. **Farm→entity link is discarded** — the farm RPC returns `(farm_id, entity_id)` but the caller drops `entity_id` (`farm_repository_impl.dart:108`); `createFarm` also drops it (`:130`). The app never retains which `core.entities.id` owns the farm.
4. **No frontend `core.entities.id` for farm scoping** — `getUserFarms()` is RLS-only (`farm_repository_impl.dart:245`), `FarmEntity` has no entity/owner field, and nothing maps `users.profiles.id → core.entities.id`. Farms therefore appear only if backend RLS happens to return them; farms owned under the pre-alignment contract become invisible, cascading to fields/assets/activities (all farm-id-scoped downstream).

## 2. Correct consumers

- Marketplace **reads**: browse (global), by-seller (`.eq('entity_id', listing.entityId)`), seller profile 2-hop via entity (`marketplace_remote_data_source.dart:330,365`).
- Business Hub inventory/listings/members: `.eq('entity_id', activeBusiness.id)` against `core.entities.id` (`business_hub_remote_data_source.dart:129-469`).
- Business Hub my-entities: RLS-scoped `core.entities` select (correct pattern, `:104`).
- Farm downstream queries (fields/assets/activities/production/financial) are farm-id-correct once the farm list itself is correct.
- Session profile lookup by `auth_user_id` is correct.

## 3. Ambiguous consumers

- `core.entities.owner_id` semantics: `fetchEntityOwnerId` returns it and labels it "owner profile id" while the RLS comment says owner_id "defaults to `core.auth_user_id()`" (`business_hub_remote_data_source.dart:265-275` vs `:104-107`). `owner_id` (possibly `auth.users.id`) and `entity_members.profile_id` (`users.profiles.id`) are different domains — any equality between them would be wrong. Needs a backend contract statement (NOT ESTABLISHED FROM CODE).
- Two context controllers exist (`context_notifier.dart` vs `context_controller.dart`); only `context_controller.dart` is wired to `contextProvider` (`context_provider.dart`). `ContextNotifier` is dead-but-present — a drift hazard.

## 4. Provider / cache invalidation problems

- **No data invalidation on workspace/entity switch.** `switchWorkspace` only mutates workspace state (`active_workspace_provider.dart:156-158`); it does not invalidate farm, marketplace, business, or dashboard data providers. The bottom-nav Dashboard *page* follows the workspace (`unified_dashboard_host.dart:40-41`), but the underlying farm list / my-businesses lists do not reload for the new context.
- `contextProvider` invalidation on switch: `ContextController` has no switch that triggers a data cascade; its `init()` is only called at boot (`main.dart:361`).
- **Good:** demo/live providers key on `isAuthenticatedProvider`, so sign-in/out correctly rebuilds (`farm_repository_provider.dart`, `business_hub_repository_provider.dart`). Hierarchy-driven invalidations only cover farm dashboard/lifecycle/AI (`hierarchy_cascade_coordinator.dart`), not marketplace/business identity data.

## 5. Workspace / navigation problems

- Workspace → Dashboard page switching is wired (workspace type → primary module landing), but switching does not switch the **active entity context**, so a "Trader Dashboard" is shown while farm/marketplace data still reflects the previously selected farm/entity. No single "active entity" is promoted into a provider that the data lists watch.
- No entity-switch UI or provider exists; role is hardcoded via the fake context engine.

## 6. Exact files requiring changes (proposed only)

1. `lib/core/context_engine/services/context_sync_service.dart` — replace fabricated context with a real profile/entity fetch (backend RPC returning `users.profiles` + active `core.entities`), or remove reliance on it.
2. `lib/core/context_engine/controllers/context_controller.dart` — resolve/own the real active `core.entities.id`; persist + restore it.
3. `lib/features/marketplace/presentation/widgets/listing_form_widget.dart` — auto-fill `entity_id` from the active entity provider; remove the manual UUID text field.
4. New or existing "active entity" provider consumed by farm + marketplace + business_hub list providers.
5. `lib/features/farm_management/infrastructure/repositories/farm_repository_impl.dart` — retain the RPC-returned `entity_id` (store on the Farm model/context); pass it (or let RLS) scope farms.
6. `lib/features/farm_management/domain/entities/farm_entity.dart` — carry `entityId`/`ownerId`.
7. `lib/features/farm_management/application/providers/farm_context_provider.dart` — source role/entity from the real active-entity provider, not the fabricated context.
8. `lib/core/workspace/application/active_workspace_provider.dart` (or a coordinator) — invalidate data providers on workspace/entity switch.
9. Remove dead `farm_remote_data_source.dart` / `context_notifier.dart` (drift hazard) — optional.

## 7. Recommended order of fixes

1. **Kill the fabricated context first** (context_sync_service + context_controller) — otherwise any downstream fix reads poisoned identity.
2. **Introduce one real "active entity" provider** sourced from `users.profiles → core.entities` (RLS-scoped), persisted + restored.
3. **Auto-bind entity_id in listing creation** (remove manual field) — restores marketplace listing visibility.
4. **Retain farm `entity_id` from the RPC** and carry it on `FarmEntity`; have farm queries use the active-entity context (or continue RLS-only, now backed by a real entity id).
5. **Wire workspace/entity switch → provider invalidation** for farm/marketplace/business/dashboard lists.
6. Resolve the `owner_id`/`profile_id` ambiguity against a backend contract statement.

**Notes / NOT ESTABLISHED FROM CODE:** the three "protected production listings" are not referenced anywhere in the codebase (DB-seeded only); the exact RLS predicates on `farms`, `marketplace.listings`, and `core.entities`; whether `core.entities.owner_id` stores `auth.users.id` or `users.profiles.id`.

**No code, provider, routing, database, or data changes were made.**
