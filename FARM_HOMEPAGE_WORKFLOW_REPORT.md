# FAMHUB Farm Homepage Workflow Report

## Date

2026-09-04

## Architecture found

The Farm Homepage is `FarmHomePage` and preserves these tabs:

1. Overview
2. My Farms
3. Crops
4. Livestock
5. Activity Logs
6. Reports

Crops and livestock are unified biological assets loaded from
`farm_management.assets`, distinguished by `asset_type`. The selected farm,
field, and asset are maintained by `hierarchyProvider`.

## Activity integration

`ActivityCreationPage` requires a selected asset and creates an activity
through `FarmRepository.createActivity`.

The repository calls:

`farm_management.create_activity(activity_data: jsonb)`

The payload contains only:

- `asset_id`
- `activity_type_id`
- `performed_at`
- `notes`

The scalar UUID returned by the RPC is used as the activity ID.

## Harvesting to production

When the activity type is `harvesting`, the UI collects:

- quantity
- canonical unit
- canonical output commodity

After the activity is created, the repository calls:

`farm_management.create_production_record(p_production_data: jsonb)`

The production payload contains:

- `activity_id`
- `quantity`
- `unit_id`
- `source_type: activity`
- `output_commodity_id`

The scalar UUID returned by the RPC is used as the production ID.

Non-harvesting activities do not automatically create production.

## Stock behavior

Flutter does not insert, update, or delete `commerce.stock_movements` or
`commerce.stock_registry` for harvesting.

The backend owns the chain:

`Production -> stock movement -> stock registry balance`

After production, existing activity, production, stock, and hierarchy-related
providers are invalidated or refreshed.

## Duplicate submission and errors

The activity form disables submission while saving and shows a loading state.
It does not automatically retry production.

If activity creation succeeds but production fails, the UI reports that the
activity was saved while production and stock completion failed. No direct
stock fallback is attempted.

## Livestock unit handling

Livestock harvesting remains blocked when no authoritative canonical output
unit is available. The frontend does not invent or hardcode a unit such as
`kg`.

## Relevant files

- `lib/features/farm_management/presentation/pages/farm_home_page.dart`
- `lib/features/farm_management/presentation/pages/activities_page.dart`
- `lib/features/farm_management/presentation/pages/activity_creation_page.dart`
- `lib/features/farm_management/infrastructure/repositories/farm_repository_impl.dart`
- `lib/features/farm_management/application/providers/activities_provider.dart`
- `lib/features/farm_management/application/providers/production_provider.dart`
- `lib/features/farm_management/application/providers/farm_live_providers.dart`
- `lib/features/farm_management/application/providers/hierarchy_cascade_coordinator.dart`

## Validation

`git diff --check` passed for the implementation changes.

Flutter analyzer and web build could not execute in the current environment:
the Flutter runtime terminates with Illegal Instruction (exit 132) before
analysis or compilation starts.

No backend or database files were modified.
