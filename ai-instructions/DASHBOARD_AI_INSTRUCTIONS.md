FAMHUB DASHBOARD_ENGINE AI ASSISTANT INSTRUCTIONS (v3.0)
📌 1. CORE RULE

The dashboard engine is a pure runtime consumer layer inside the FAMHUB OS architecture.

It does NOT own:

module authority
registry authority
permissions
feature governance

Those belong ONLY to:

core/system/registry
core/system/module_control

Dashboard engine ONLY:

consumes runtime module state
builds composition graphs
performs reactive rendering
manages incremental UI updates
🔁 SYSTEM FLOW (MANDATORY)
Supabase / Backend
        ↓
system/registry
        ↓
system/module_control
        ↓
module_runtime_adapter
        ↓
DashboardCompositionEngine
        ↓
CompositionSnapshot
        ↓
SnapshotDiff
        ↓
DashboardRenderer
        ↓
UI
📌 2. STRICT LAYER RESPONSIBILITIES
🔹 DOMAIN LAYER

Contains PURE runtime models and value objects ONLY.

✔ Allowed:

CompositionNode
LayoutContext
WidgetIdentity
ModuleKey
WidgetKey

❌ Forbidden:

Flutter imports
Supabase access
business logic
rendering logic
🔹 APPLICATION LAYER

Responsible for runtime orchestration and decision pipelines.

✔ Allowed:

composition logic
diff calculation
event orchestration
layout resolution
widget scoring
usage tracking
reactive runtime flow

Includes:

DashboardCompositionEngine
SnapshotDiff
LayoutResolver
WidgetScoringService
DashboardEventBus

❌ Forbidden:

direct Supabase calls
Flutter UI rendering
registry authority ownership
🔹 INFRASTRUCTURE LAYER

Responsible for external integrations and runtime adapters.

✔ Allowed:

module runtime adaptation
repository implementation
caching
remote sync
realtime integration

Includes:

module_runtime_adapter.dart
composition_cache.dart
dashboard_remote_sync.dart
dashboard_repository_impl.dart

❌ Forbidden:

layout authority
module governance
composition ownership
🔹 PRESENTATION LAYER

Responsible for rendering ONLY.

✔ Allowed:

renderer widgets
UI pages
widget builders
rendering isolation
zone rendering

Includes:

DashboardRenderer
DashboardRendererWidget
DashboardEnginePage
WidgetBuilderRegistry

❌ Forbidden:

business logic
composition decisions
Supabase access
module activation logic
📌 3. SYSTEM AUTHORITY RULE (CRITICAL)
✅ ONLY system layer may own:
module contracts
module definitions
module registration
feature flags
permissions
activation logic
dependency resolution

Located ONLY in:

core/system/registry
core/system/module_control
❌ DASHBOARD_ENGINE MUST NEVER:
define module authority
create registry ownership
duplicate module definitions
own feature flags
decide permissions
override module activation

Dashboard engine is a CONSUMER ONLY.

📌 4. REGISTRY RULE (NON-NEGOTIABLE)
✅ VALID REGISTRY LOCATION

ONLY:

core/system/registry
❌ FORBIDDEN
dashboard_engine/registry
dashboard registry duplication
local dashboard authority

Dashboard engine registry folders are forbidden.

📌 5. ADAPTER RULE
✅ module_runtime_adapter.dart

Location:

dashboard_engine/infrastructure/adapters/

Purpose:

transform runtime module state
normalize module data for composition
adapt system layer into runtime consumption format
❌ ADAPTER MUST NEVER:
own permissions
store feature flags
govern activation
define modules
mutate registry authority

Adapter must remain:

thin
stateless
transformation-only
📌 6. COMPOSITION RULE

Dashboard composition MUST follow:

Resolved Runtime Modules
        ↓
Composition Engine
        ↓
Composition Snapshot
        ↓
Snapshot Diff
        ↓
Renderer
✅ Composition Engine Responsibilities
build composition graph
order nodes
zone assignment
snapshot generation
❌ Composition Engine MUST NEVER:
render widgets directly
access Supabase
define permissions
perform module governance
📌 7. RENDERER RULE
✅ Renderer Responsibilities
render composition nodes
apply incremental updates
maintain widget cache
isolate UI rebuilds
❌ Renderer MUST NEVER:
decide layouts
load modules
resolve permissions
fetch backend data
📌 8. DIFF RENDERING RULE

Dashboard engine uses:

CompositionSnapshot
        ↓
SnapshotDiff
        ↓
Incremental Renderer Updates
✅ Allowed Optimizations
snapshot diffing
widget caching
isolated rebuilds
reactive streams
composition memoization
❌ Forbidden Optimizations
duplicated composition trees
local registry systems
renderer-owned state authority
layout duplication logic
📌 9. REACTIVE ENGINE RULE

Dashboard engine is fully reactive.

Triggers include:

module activation changes
feature flag updates
entity switching
role changes
realtime sync updates
✅ Reactive Flow
system.module_control
        ↓
module_runtime_adapter
        ↓
stream update
        ↓
composition rebuild
        ↓
snapshot diff
        ↓
incremental render
📌 10. PERFORMANCE RULES

System must maintain:

deterministic composition flow
minimal rebuild surface
incremental rendering only
bounded widget cache
stable memory footprint
zero duplicated authority
📌 11. EXTENSION RULE

When adding new functionality:

Responsibility	Layer
Module governance	system/module_control
Registry ownership	system/registry
Runtime adaptation	infrastructure/adapters
Composition logic	application/composition
Layout resolution	application/resolution
Rendering	presentation/renderer
UI widgets	presentation/widgets
Realtime sync	infrastructure/sync
Caching	infrastructure/cache
📌 12. GOLDEN RULE
System layer decides IF modules exist
Dashboard engine decides HOW runtime UI is composed
Renderer decides HOW UI is painted
Diff engine decides WHAT changed