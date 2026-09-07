# FAMHUB Commercial / Trader Workspace — Contract Mapping & Architecture Audit

Scope: `famhub/docs` (authoritative backend), `lib/features/farm_management` (benchmark), marketplace/commerce/financing/logistics/opportunities features, and `lib/core` runtime (workspace, capabilities, dashboard engine, router, session). Nothing was modified.

---

## 1. Backend schema map

Sources: `docs/Backend schemas/{core,commerce,marketplace,farm_management,users,auth,system,media,spatial,storage}.md`. Note: the docs are **table DDL only** — functions/views/RPCs are not documented there; RPC contracts below are those actually invoked by existing code.

### 1a. Core (identity, taxonomy, entities)
| Table | Purpose | PK | Ownership / user rel | Key FKs / status / enums |
|---|---|---|---|---|
| `users.profiles` | Person identity (one row per auth user) | `id` | `auth_user_id` unique → `auth.users` | `user_type`: `farmer\|trader\|stakeholder`; `profile_status`, `account_status`, `kyc_status`, `role_id`; location FKs |
| `core.entities` | **Canonical business/commercial entity** | `id` | `owner_id` → profiles (default `core.auth_user_id()`), `primary_contact_profile_id` | **`entity_type`: `farm\|trading_company\|service_provider\|cooperative\|individual_pro\|agrovet`**; `verification_status`, `is_active`, `slug`, `legal_owner_type` |
| `core.entity_members` | People attached to an entity | `id` | `profile_id`, `entity_id` | `role_id` → `core.user_roles`; `can_sell`, `can_manage`, `can_receive_payments`, `membership_status` |
| `core.entity_roles` / `entity_invitations` / `entity_role_scopes` | Role assignment, invitations, scoping | `id` | profile + entity + role | role scopes `entity\|global\|module` |
| `core.entity_context_sessions` | **Canonical workspace/context switcher** | `id` | `user_id`, `entity_id`, `is_default`, `session_status` | **`active_mode`: `farmer\|trader\|buyer\|business_rep\|supplier\|admin\|agrovet`**; FK `business_profile_id` → `commerce.business_profiles`, `active_role_id` → user_roles |
| `core.user_roles` / `permissions` / `role_permissions` / `permission_overrides` | RBAC | `id` | — | permission `code`, `module` |
| `core.domains` → `categories` → `items` → `item_variants` | **Canonical product taxonomy** | `id` | — | variant attributes; `item_unit_map`, `unit_conversions`, `units` |
| `core.records` | Generic classified record attached to an entity | `id` | `entity_id` NOT NULL, `created_by` | `domain_id/category_id/item_id/variant_id`, `status`, `activity_type_id` → `farm_management.activity_types` |
| `core.commodities` | Produce master (name, category, hs_code, perishable, shelf_life) | `id` | — | linked to listings/stock via `output_commodity_id` on production |
| `core.attribute_registry` + attribute map tables | Dynamic attributes at category/item/variant/record level | `id` | — | — |
| `core.locations`, `countries`, `geography_levels`, `infrastructure*` | Geography & facilities (markets etc.) | `id` | — | `locations` has level hierarchy |
| `core.unlocks_expiry_log` | buyer/seller contact-unlock expiry log | `id` | supplier/buyer/listing refs | — |

### 1b. Commerce (order/inventory/payment engine)
| Table | Purpose | PK | Ownership | Status / enums | Key FKs |
|---|---|---|---|---|---|
| `commerce.business_profiles` | **Seller/business profile** (what the marketplace seller record points to) | `id` | `entity_id` NOT NULL → `core.entities`; `primary_contact_id` → profiles | **`entity_type`: `individual\|company\|agrovet\|cooperative\|trader`**; `verification_status`; `ownership_scope` `personal\|organizational` | supplier_name, county/subcounty/ward (locations), rating, business reg/KRA/license fields |
| `commerce.stock_registry` | **Canonical inventory** (quantity on hand per variant) | `id` | `entity_id` → entities; `business_profile_id` | status `active\|depleted\|archived`; `quantity>=0`, `reserved_quantity` | `variant_id`/`product_id` → core, `unit_id`, `location_id` |
| `commerce.stock_movements` | Ledger of quantity changes | `id` | `entity_id` | **`movement_type`: `harvest\|purchase\|sale\|loss\|adjustment\|transfer_in\|transfer_out`**; `trade_type` `local\|intercounty\|export\|import`; `source_module/source_type/source_ref_id` | `stock_id`, `order_id`, `transaction_id`, `destination_location_id` |
| `commerce.stock_reservations` | Reserved qty tied to listings/orders | `id` | — | status `reserved`… | stock/listings/orders |
| `commerce.orders` | **Order header** (marketplace listing order) | `id` | `buyer_id` → profiles; `supplier_id` → **business_profiles**; `entity_id`, `business_profile_id` | **`status`: `pending\|confirmed\|shipped\|delivered\|cancelled\|returned`**; `payment_status`; `payment_mode` `direct_supplier\|platform\|escrow` | `listing_id` → marketplace.listings; `unit_id` |
| `commerce.order_items` | Order lines | `id` | — | — | order, listing_id, `stock_id`, `variant_id`, `unit_id` (+ denormalised `product_id` col, no FK) |
| `commerce.purchase_orders` | **Buy-side** purchase orders | `id` | `created_by` → profiles; `supplier_id` → business_profiles | status `pending\|sent\|received\|cancelled` | — |
| `commerce.transactions` | Payment transactions per order | `id` | `supplier_id` → business_profiles; `profile_id` | payment_method `mpesa\|visa\|card\|bank`; payment_status incl. `refunded`; `recorded_by` `supplier\|buyer\|system` | `order_id` |
| `commerce.payments` | Payment records | `id` | `payer_id` → profiles; `supplier_id` → business_profiles | payment_status | order_id |
| `commerce.supplier_payments` | Platform charges to sellers | `id` | supplier | payment_type `registration\|subscription\|listing\|transaction` | — |
| `commerce.supplier_payment_methods`, `supplier_pricing` | Seller payout rails & fee schedule | `id` | supplier | method `mpesa\|bank\|paybill\|till` | — |
| `commerce.entities_audit` | Audit of entity changes | `id` | changed_by | operation | entity_id |

### 1c. Marketplace
| Table | Purpose | PK | Status / enums | Notes |
|---|---|---|---|---|
| `marketplace.listings` | **Sell-side offer over stock** | `id` | `status` (text), `contact_visibility` `locked\|open` | `entity_id` → entities; `stock_id` → stock_registry; `variant_id`, `location_id`, `unit_id`; `is_promoted` |
| `marketplace.contact_unlocks` | Buyer pays to unlock seller contact | `id` | payment_status; `unlocked` | listing + entity |
| `marketplace.market_prices` / `daily_market_prices` | Market price reference | `id` | — | location/market + variant + unit |
| `marketplace.markets` | Physical markets | `id` | — | location_id |
| `marketplace.buyer_pricing` | Unlock pricing | `id` | action `contact_unlock` | — |

### 1d. Other schemas
- `system.modules`, `system.feature_flags`, `system.workflow_*`, `system.billing_accounts`, `subscription_plans`, `active_subscriptions`, `invoices`, `wallet_balances`, `payout_*`, `commission_rules`, `revenue_ledger`, `kpi_definitions/snapshots`, `dashboard_metrics`, `entity_performance_scores`. **Note: `system.workspaces` is read by the frontend but is NOT in the docs.**
- `media.files` (context-typed files) — used for listing images.
- Farm mgmt tables (`farm_management.*`) — farms/fields/assets/activities/production_records/financial_records/farm_kpis etc. (already covered by the farm feature; inventory entry point into commerce is via production trigger).
- `users.alerts` exists in docs; frontend notifications feature is a scaffold.

### 1e. Known RPC/function contracts (from code, NOT in schema docs)
- `commerce.create_farm_with_auto_entity(farm_data jsonb) → {farm_id, entity_id}` — creates farm + `core.entities` row server-side (`farm_repository_impl.dart:48-61`).
- `farm_management.create_crop_livestock_asset`, `create_activity`, `create_production_record` — farm-scoped writes; `entity_id` server-derived.
- `marketplace.publish_listing_from_stock(p_stock_id, p_price_per_unit, p_title, p_description, p_images)` — creates listing from owned stock under RLS (`marketplace_remote_data_source.dart:281-307`).
- `marketplace.update_listing(p_listing_id, p_changes jsonb)`, `marketplace.set_listing_status(p_listing_id, p_status)`.
- Edge functions (deployed, not in repo): `create-profile`, `select-workspaces`, `upload_media`, `media_get_by_context`, `delete_media`.
- Backend triggers (documented in code comments, authoritative): production → `stock_movements` → `apply_stock_movement` → `commerce.stock_registry`.

---

## 2. Frontend architecture map (what exists)

**Stack:** Flutter + Riverpod 3 + GoRouter + supabase_flutter. Official feature template = clean architecture per module (`application/domain/infrastructure/presentation/module/config`) per `docs/FAMHUB_FEATURE_MODULE_ARCHITECTURE_STANDARD.md`.

Real (backend-wired) features: **farm_management**, **marketplace**. Everything else is a scaffold with hard-coded/demo data (financing=`finance`, logistics, opportunities, agribusiness, knowledge_link, notifications, search, analytics, reports, extension_services, agri_connect, carbon_credit, referral_hub).

### Core canonical mechanisms (must-reuse)
- **Module list is backend-driven**: `system.modules` → `ModuleService` → `moduleProvider` → `runtimeModuleRegistryProvider` → nav/dashboard/router. Static catalogs in `lib/system/registry/{module,route,feature,access,dependency}_registry.dart`.
- **Module descriptors**: `features/<m>/module/<m>_runtime_descriptor.dart` returns `ModuleRuntimeDescriptor` (dashboardWidgets, homeWidgets, quickActions, notification/search/analytics providers, routes, permissions). Registered in `core/composition/bootstrap/module_descriptor_bootstrap.dart`; page builders in `core/composition/router/dynamic_route_registrar.dart:199-249` (`ModulePageRegistry`).
- **Dashboard widgets**: `WidgetRegistry.register(widgetKey, builder, metadata)`; bootstrapped in `core/dashboard_engine/presentation/builders/phase_d_dashboard_bootstrap.dart:129-141`. Descriptor + WidgetRegistry + each widget having its own live `FutureProvider`.
- **Capabilities**: `core/capabilities` — 22 registered capability ids (relevant: `marketplace.listings`, `marketplace.orders`, `inventory.stock`, `inventory.warehouse`, `finance.recording`, `finance.invoicing`, `logistics.dispatch`, `logistics.tracking`). `CapabilityProfile` currently derived from `context.role` (`capability_profile_provider.dart:78-110`). Module/widget capability requirements via `registerModuleCapabilities(...)` + `capability_composition_bridge.dart`. Filtered providers: `capabilityFilteredDashboardWidgetsProvider`, `capabilityFilteredSidebarItemsProvider`, etc.
- **Context stack**: `EntityContext{userId, role, entityId, tier, isGuest}` (`core/context_engine`); **Organization Runtime** `activeOrganizationProvider` (`OrganizationContext.organizationType`: farmer/cooperative/aggregator/exporter/processor/enterprise/…); **Workspace** (`system.workspaces` catalog + `users.user_workspaces` selection) with `WorkspaceDashboardCatalog.modulePromotions` mapping types → modules (`farmer`→farm_management first; **`trader`→[marketplace, logistics, analytics, finance, traceability, agri_connect]**). Workspace selection at onboarding + top-bar switcher.
- **Session/auth**: `sessionProvider` (`AuthenticatedSession`), `isAuthenticatedProvider`; `showProtectedActionPrompt` for guest write-gating; guest reads swap in `Demo*Repository` (pattern in `farm_repository_provider.dart:16-24`).
- **RLS/identity**: never send `auth.uid()`/`entity_id` from the client; ownership via `core.auth_user_id()` server-side; client passes only domain payloads.

### Marketplace feature (only commerce code)
Full clean architecture. Repository + `MarketplaceRemoteDataSource` (schema-aware `.schema('marketplace'|'commerce'|'core')`; batched scalar-select + cross-schema enrichment, deliberately no FK embeds). Covers: browse listings, publish listing **from owned commerce stock** (`eligibleStockProvider` → `commerce.stock_registry`), edit/archive/status, seller profile, image/media upload. Read-only touches `commerce.business_profiles` (seller name/rating by `entity_id`).

---

## 3. Farm Management benchmark findings

Conventions a new workspace must replicate (line-level detail in the audit agent report):
1. **Layered folder spine** exactly as the standard (section 2).
2. **Hierarchy of ownership-scoped domain + context**: `farm_management` models `Farm (entity) → Field → Crop/Livestock (=assets) → Activities → Production → Reports`. Selection source-of-truth = single `NotifierProvider` (`hierarchyProvider`); derived `farmContextProvider`; every dependent list provider watches it and filters client-side; one `refreshAfterMutation()` invalidation coordinator.
3. **Dashboard = descriptor + WidgetRegistry + per-widget FutureProviders** over one page (`farm_management_page.dart`) with tabs; no Scaffold/AppBar, uses `ShellPageContent`; responsive via shared `breakpointProvider` (compactXs/mobile/tablet/desktop/ultraWide) and `AdaptiveContentGrid`/`ResponsiveWrapper`.
4. **Data discipline**: abstract repo contract (no Supabase in domain), session-aware provider swapping demo vs real impl; backend/KPI tables as canonical aggregates (`farm_kpis`) — frontend is display-only; single-row aggregate queries, never N+1 where canonical table exists; schema-qualified RPCs for ownership-creating writes.
5. **Auth/guest**: reads demo-repo for guests, writes gated by `showProtectedActionPrompt`, `ExploreBanner` in empty state.
6. **Cross-module by repository import** (farm imports `marketplaceRepositoryProvider` for publish flows), never page imports. Widget registration bootstrap + runtime descriptor registration; capabilities declared for module and widgets.
7. **RPC-failures**: some farms/asset writes also use UI-only local fields (e.g., `ActivityModel.farmId/fieldId`) that are NOT table columns — acceptable model pattern; be careful to not bake UI-only ids into repository contracts.

Farm Management is NOT to be copied literally, but a new module must match its **registration lifecycle**, **context/provider discipline**, **data-access patterns**, **shell compliance**, and **UX quality** to be first-class.

---

## 4. Commercial / Trader hierarchy (canonical mapping)

The conceptual target maps cleanly onto **existing** contracts. Canonical commercial hierarchy:

```
core.entities  (business/commercial entity; entity_type ∈ farm|trading_company|service_provider|cooperative|individual_pro|agrovet)
├── commerce.business_profiles  (marketplace seller/business facade; ownership_scope personal|organizational; 1..1..* with entity)
│   ├── 1..* facilities/locations  → core.locations / core.infrastructure (no trader-specific location model)
│   ├── products/services           → core taxonomy: domains → categories → items → item_variants (+ commodity_variants, units)
│   ├── catalog offers / services   → marketplace.listings (stock-backed)
│   ├── inventory                   → commerce.stock_registry + stock_movements + stock_reservations  (canonical; do NOT invent trader_inventory)
│   ├── procurement/buying          → commerce.purchase_orders (+ orders with supplier role)
│   ├── sales/orders                → commerce.orders + order_items (canonical marketplace order)
│   ├── payments                    → commerce.transactions / commerce.payments / supplier_payment_methods (platform billing: system.*)
│   ├── members/access              → core.entity_members / entity_roles / role_permissions / active_mode on entity_context_sessions
│   └── context/workspace           → core.entity_context_sessions (user ↔ active business ↔ role/mode)
└── User ↔ owned & member entities (users.profiles)
```

**Key confirmations / rules:**
- `core.entities` is the canonical business table; a **trading company**, an **agrovet**, a **cooperative**, a **service provider**, a **factory/processor** are all `entities` (processor/factory has **no** dedicated enum value — see §11 ambiguities). Farms already auto-create an entity; the commercial workspace assumes an equivalent server-side "create business entity" capability exists/needs confirmation.
- Products/items must use `core.items/item_variants` (no separate trader taxonomy). Marketplace owns listings; commerce owns orders & inventory; do not create second models for these.
- **Business switching** canonical backend artifact = `core.entity_context_sessions` (+ `entity_members` for multi-member businesses). The frontend equivalent does NOT yet exist (see §10); reuse this table, don't invent a "TraderContext".

---

## 5. Business types & capability mapping

Backend type vocabularies are fragmented across tables — map, don't invent:
- `core.entities.entity_type`: farm, trading_company, service_provider, cooperative, individual_pro, agrovet
- `commerce.business_profiles.entity_type`: individual, company, agrovet, cooperative, trader
- `core.entity_context_sessions.active_mode`: farmer, trader, buyer, business_rep, supplier, admin, agrovet
- frontend `WorkspaceDashboardCatalog.normalizeType` already aliases `aggregator/retailer → trader`, `input_supplier/agrovet → supplier`, `bank/financial_institution → institution`, `processor/exporter → (unmapped)`.

Proposed capability-driven composition (each capability maps to real tables):

| Business (examples) | Capability set (→ data source) |
|---|---|
| Produce trader / aggregator | Sourcing & procurement (`purchase_orders`), aggregation/collections (via stock movements `transfer_in`), quality (stock metadata/`activity_types`→reuse), inventory (`stock_registry`), listings (`marketplace.listings`), orders (`commerce.orders`), logistics (`logistics.*` module + `stock_movements.destination_location`), payments (`commerce.transactions/payments`) |
| Mama Mboga / retailer / wholesaler | Procurement (purchase_orders), inventory (stock_registry + movements `purchase`/`sale`), sales & orders, customers (profiles/entities), payments |
| Input supplier / agrovet / equipment supplier | Catalog (marketplace listings over stock of input variants), inventory, purchases, sales, orders, payments |
| Labour service provider | Service catalog/availability → currently **no backend contract** (gap); closest: `core.item_variants` (service) + `entity_type=service_provider`; jobs/bookings → missing; earnings → commerce payments |
| Factory / processor / mill / packhouse | Raw-material procurement (`purchase_orders`, movements `purchase`/`transfer_in`), receiving, production (farm-style production_records equivalent or `core.records` + stock `harvest`-like movements), raw + finished inventory (`stock_registry`), quality, orders + dispatch, sales, payments |
| Bank / SACCO / MFI | finance workspace (`finance` module scaffold + `system.billing/wallets/loans-equivalents`) — **no backend financing schema documented** (gap) |
| Exporters / logistics / hotels/bulk buyers | trade_type `export/import/intercounty` on stock_movements; listings + orders (buyer side); logistics module scaffold |

Frontend **capability ids** to drive composition already exist: `marketplace.orders`, `inventory.stock`, `inventory.warehouse`, `finance.recording/invoicing`, `logistics.dispatch/tracking`, `analytics.*`, `workflow.execution`. The dashboard should compose from these capabilities + org/workspace type — **not** `if (businessType == aggregator)` branching.

---

## 6. Cross-module integration map

| FAMHUB module | Commercial workspace connection | Contract used |
|---|---|---|
| Farm Management | Farms produce → commerce stock (server trigger). Farmer also sells → same listings/orders surfaces. No farm code changes needed; commercial workspace merely reads shared commerce tables | `production_records`→stock trigger; `farms.entity_id` |
| Marketplace | Listings = the sell-side catalog of the business. Publish is already entity/RLS-scoped | `marketplace.listings`, `publish_listing_from_stock` |
| Commerce | Orders, order_items, purchase_orders, transactions/payments, stock_registry/movements/reservations — the operational core | all `commerce.*` tables above |
| Taxonomy (`core.*`) | Items/variants/units/commodities/locations are the shared reference | read-only, batched |
| Identity (`users`/`auth`, `core.entities`, `entity_members`) | One user ↔ many entities; members share a business | `entity_context_sessions` (switch), `entity_members` (RBAC) |
| System/finance runtime | Billing, wallet, payouts, invoices, subscriptions, KPI snapshots, dashboard metrics (mostly bank/finance-oriented) | `system.*` |
| Knowledge Link | Commercial users consume knowledge content (module is scaffold; surface via descriptor contribution later) | descriptor |
| Financing (banks/SACCOs/MFIs) | Finance workspace = the "institution" dashboard; no backend financing schema documented — treated as future cross-module surface, not built now | — |
| Notifications | Existing app has event bus + notification scaffold; reuse `notificationProviders` in descriptor when real | descriptor |
| Guest/Auth | Same session rules as farm | session/guest/auth_guard |

**Integration rule observed in codebase:** cross-module access happens through **repositories/providers**, never page/widget imports; all ownership claims stay server-side.

---

## 7. Pages / routes required

Recommended single feature `lib/features/commercial` with a **trader/commercial workspace root** (module key `commercial` or reuse an existing `system.modules` key if the backend later defines one; initial code-side key proposed below as confirmable). Descriptor `route: '/commercial'`; workspace mapping: make it the primary module for `trader` (and via `modulePromotions` for aggregator/retailer/supplier/commercial aliases), so `/` on the trader workspace lands here.

Pages (all sub-navigation = imperative `Navigator.push(MaterialPageRoute)`, matching farm/marketplace convention; only module root goes in GoRouter):
- `commercial_home_page.dart` (workspace landing; business selector + capability-composed dashboard)
- Business: `business_onboarding_page.dart` (create/register entity + profile), `business_detail_page.dart`, `business_switch_page.dart` (reuse shell app-bar switcher semantics if canonical)
- Product/inventory: `catalog_page.dart`, `product_form_page.dart`, `inventory_page.dart`, `stock_adjust_page.dart`
- Sell: reuse marketplace pages (`StockSelectionPage`, `PublishListingPage`, `ProductDetailsPage`) — do NOT re-create
- Buy/procurement: `purchases_page.dart`, `purchase_order_page.dart`, `suppliers_page.dart` (partially reuse `SellerProfilePage`)
- Orders/sales: `orders_page.dart`, `order_detail_page.dart`
- Customers: `customers_page.dart`
- Payments: `transactions_page.dart`
- Capability sections hosted as dashboard widget descriptors, not separate routes.

Static registrations to add: `system/registry/{module,route,feature,access,capability}_registry.dart`, `ModulePageRegistry.register('commercial', …)`, `ModuleDescriptorRegistry.register(createCommercialDescriptor())`, `WidgetRegistry` widget bootstrap in phase D, `registerModuleCapabilities`.

---

## 8. Providers / repositories / models required

Domain (`commercial/domain`):
- `entities/`: `business_entity.dart` (core.entities), `business_profile.dart` (commerce.business_profiles), `inventory_item.dart`, `order.dart`, `purchase_order.dart`, `transaction.dart`, `payment.dart`, `customer.dart` (reuse marketplace `Listing`, `StockItem` where applicable)
- `models/`: `commercial_dashboard_summary.dart`, `business_metrics.dart`, `commercial_filter_model.dart`, `capability_composition.dart`
- `repositories/`: abstract `CommercialRepository` (business, inventory, orders, purchases, payments, transactions, customers)
- `services/`, `value_objects/` (Money/Price/Quantity — reuse marketplace VOs), `enums/`

Infrastructure:
- `commercial_remote_data_source.dart` (schema-aware reads of commerce/core; **copy the batched enrichment pattern**, not FK embeds)
- `commercial_repository_impl.dart` (+ `DemoCommercialRepository` for guests)
- `services/` mappers/error mappers

Application providers: `commercialRepositoryProvider` (session-aware demo/real switch), `businessContextProvider` (active business = single source of truth), `businessesProvider`, `inventoryProvider`, `ordersProvider`, `purchasesProvider`, `transactionsProvider`, `commercialDashboardProvider`, per-widget live `FutureProvider`s, `commercialWidgetDescriptors…` reuse.

Core context: resolve active business from `activeOrganizationProvider` + `entity_context_sessions` (when frontend support lands) — **do not add a parallel singleton**.

---

## 9. What can be reused

- All marketplace domain entities/models/enums/VOs/repo contract + impl + data-source read helpers, providers (`eligibleStockProvider`, `listingDetailsProvider`, `sellerListingsProvider`, KPI live providers), pages/widgets (`StockSelectionPage`, `PublishListingPage`, `ProductDetailsPage`, `SellerProfilePage`, `ListingTile/Card/Badge`), image processing service, error mappers.
- Commerce read patterns (`commerce.stock_registry`, `business_profiles`, `core.*` batched lookups) from `marketplace_remote_data_source.dart`.
- Core: workspace/type normalization + `modulePromotions`, org runtime, context engine, session/auth/guest (`showProtectedActionPrompt`, demo-repo switch pattern), capability framework + all `CapabilityFiltered*` providers, `WidgetRegistry` + phase-D bootstrap, descriptor/model system, `ModuleRegistry`/`RouteRegistry`, GoRouter `DynamicRouteRegistrar`/`ModulePageRegistry`, shared layout/state widgets (`ShellPageContent`, `ResponsiveWrapper`, `AdaptiveContentGrid`, `LoadingStateWidget`, `ErrorStateWidget`, `EmptyStateWidget`, KPI/summary/header widgets), event bus + workflow orchestrator invalidation.
- Farm-management: the whole "module lifecycle template" (descriptor+registration+repo-switch+context discipline), plus its taxonomy helpers against `core.*`.

## 10. What is missing (frontend gaps, not to solve by inventing backend)

1. **Business/entity frontend** — no UI/models/repo for `core.entities` (list/create/switch "my businesses"), no read of `core.entity_members`/`entity_context_sessions`, no active-business selector; commercial workspace landing `/` for `trader` currently is the plain MarketplacePage.
2. **Commerce order frontend** — no `commerce.orders`/`order_items`/`purchase_orders` model, repo, page, or write (buyer flow, cart/checkout, seller order management). Missing entirely; this is the bulk of the new feature.
3. **Transactions/payments UI** — `commerce.transactions/payments/supplier_payment_methods` unused; profile "Payment Methods/Transaction History" rows non-functional.
4. **Inventory operations UI** — seller-side stock adjust/transfer/movements screens absent (only farm-`assets`-based ops and marketplace publish exist).
5. **Business-profile editor / become-supplier / onboarding** — none (only static CTA + read-only lookups).
6. **Contact-unlock / marketplace buyer engagement** — static banner only.
7. **Labour/equipment/services catalog + job/booking** — no backend contract; scaffold only.
8. **Financing (banks/SACCO/MFI) data** — `finance` module is scaffold; no backend financing schema doc; do not build dashboards with no data source.

## 11. Backend / schema ambiguities (require confirmation before implementation)

1. **No docs for functions/RPCs/views** — RPC names/signatures only discovered from code. There is no documented `create_trading_company_with_auto_entity` (only `create_farm_with_auto_entity`). Need confirmation of an entity-creation RPC for non-farm businesses, or whether a generic create-business RPC exists.
2. **`system.workspaces` & `users.user_workspaces`** are read by the frontend but are **not in the schema docs**. Confirm tables/columns + whether workspace types (trader/retailer/aggregator/supplier/institution…) are seeded.
3. **Business-type taxonomy divergence**: `entities.entity_type` has no `factory/processor/mill/packhouse/bank/sacco/mfi/logistics/restaurant` values; `business_profiles.entity_type` differs from `entities.entity_type`; `active_mode` differs again; frontend `OrganizationType` enum (aggregator/exporter/processor/enterprise/financial/logistics) differs from all of them. Must define the canonical mapping + how a factory/bank registers as an `entity`.
4. **`core.entity_context_sessions`** is documented but has no frontend wiring and no confirmation whether it is the intended canonical active-business table or aspirational. Also business-scoping of commerce data (orders tied to business_profile vs entity vs profile) needs confirmation (orders have `supplier_id`→business_profiles **and** `entity_id`; stock_registry has entity_id + business_profile_id).
5. **Product/stock linkage to taxonomy**: `order_items.product_id` exists w/o FK; stock requires `variant_id`; produce listings use commodities indirectly. Confirm the intended item→variant→commodity mapping for commerce catalogs.
6. **Finance backend contract absent**; buyer-side flows (unlock) partially specified only. For Phase 1 these are read-as-unknown.

## 12. Recommended implementation sequence

Follow the requested phases; phases 1–5 are prerequisites (skip nothing):
- **Phase 1 — Contract mapping (this report)** → review/confirm §11 ambiguities (esp. #1–#4) with backend owner.
- **Phase 2 — Domain models**: `business_entity`, `business_profile`, `inventory`, `order`, `purchase_order`, `transaction`, `payment`, DTO/summary models; reuse marketplace/core VOs.
- **Phase 3 — Repositories/data sources**: `CommercialRepository` + impl + schema-aware data source (copy marketplace batched-lookup pattern); demo repo for guest.
- **Phase 4 — Providers/state**: repo provider (session-aware), active-business context provider (+ cascade invalidation coordinator like `hierarchyCascadeCoordinator`), per-domain list providers, dashboard provider, per-widget live providers.
- **Phase 5 — Workspace routing/context**: descriptor + module/page/widget registration; workspace-type promotion (`trader`/`aggregator`/`retailer`/`supplier`/`commercial`); capability declarations.
- **Phase 6 — Base Commercial Dashboard**: business selector (canonical: `entity_context_sessions` + org runtime), summary, capability-composed metric cards with real sources, quick actions, alerts, recent orders/transactions; responsive via shared layout; guest demo/empty/auth states.
- **Phase 7 — Capability sections** (not per-trader dashboards): inventory, sales/orders, purchases, payments sections conditional on capabilities + data presence.
- **Phase 8 — Detail/operational pages**: business detail, inventory ops, order management, procurement; reuse marketplace sell pages; marketplace buyer/order flow only if contract confirmed.
- **Phase 9 — Cross-module integrations**: marketplace publish (reuse), farm-to-stock visibility, knowledge/finance/notifications surfaces via descriptors.
- **Phase 10 — Tests + `flutter analyze` + cleanup** (check `test/` conventions first).

Estimated new scope is concentrated in the **commerce frontend** (orders/purchases/transactions/inventory-ops + business entity/context) — the exact areas §10 confirms are greenfield.

Awaiting review of this mapping (especially §4, §5, and §11) before any substantial implementation begins.
