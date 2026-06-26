MASTER DEVELOPMENT RULEBOOK (FAMHUB v5.0 — FINAL OS SPEC)
🧠 SOURCE OF TRUTH

FAMHUB follows a strict:

Backend-controlled modular Agricultural Operating System (AOS)

Architecture authority resides in:

core/system/registry
core/system/module_control

Flutter is a:

runtime rendering and interaction layer

NOT the system authority.

📌 1. CORE IDENTITY

FAMHUB is an:

🧠 Agricultural Operating System (AOS)

NOT:

marketplace app
farm tracker
SaaS dashboard
monolithic ERP
🌍 SYSTEM SCOPE
Production
→ Operations
→ Traceability
→ Marketplace
→ Commerce
→ Finance
→ Insurance
→ Analytics
→ Governance
📌 2. FINAL ARCHITECTURE STRUCTURE (LOCKED)
lib/
├── app/              → bootstrap only
├── core/             → infrastructure backbone
├── features/         → business modules
├── shared/           → reusable UI system only
└── system/           → OS authority + governance
📌 3. ARCHITECTURE RESPONSIBILITY MAP
🔹 app/

Purpose:

startup only
bootstrap only
app initialization only

Allowed:

main.dart
app initialization
dependency bootstrap

❌ Forbidden:

business logic
module logic
rendering orchestration
🔹 core/

Purpose:

infrastructure runtime backbone

Contains:

router
shell
guards
context engine
database services
providers
theme
dashboard_engine
infrastructure services
🔹 features/

Purpose:

business capability modules

Every feature must be:

self-contained
modular
OS-pluggable
🔹 shared/

Purpose:

reusable UI system only

Allowed:

cards
inputs
layouts
UI helpers
visual states

❌ Forbidden:

business logic
repositories
Supabase
module governance
🔹 system/

Purpose:

OS authority layer

Contains:

registry authority
module governance
permissions
lifecycle management
dependency resolution
feature activation
📌 4. SYSTEM LAYER (CRITICAL)
✅ system/registry/

Responsible for:

module discovery
module registration
known module metadata
OS registry authority

Contains:

module_registry.dart
✅ system/module_control/

Responsible for:

runtime activation
feature enablement
permissions
dependency validation
module loading
lifecycle governance

Contains:

module_contract.dart
module_definition.dart
module_loader.dart
❌ FORBIDDEN

No duplicate registry systems outside:

system/registry
📌 5. DASHBOARD_ENGINE ARCHITECTURE (LOCKED)

Dashboard engine is located in:

core/dashboard_engine/

Dashboard engine is:

a pure runtime consumer engine

It does NOT own:

module authority
registry authority
feature governance
permissions
✅ DASHBOARD_ENGINE RESPONSIBILITIES
runtime composition
reactive rendering
snapshot generation
diff rendering
layout resolution
UI orchestration
❌ DASHBOARD_ENGINE MUST NEVER
define modules
own registry systems
manage permissions
control feature flags
override module governance
📌 6. FINAL DASHBOARD_ENGINE STRUCTURE
core/dashboard_engine/
│
├── engine.dart
│
├── application/
│   ├── composition/
│   ├── events/
│   ├── intelligence/
│   ├── resolution/
│
├── domain/
│   ├── models/
│   ├── value_objects/
│
├── infrastructure/
│   ├── adapters/
│   ├── cache/
│   ├── repository/
│   ├── sync/
│
├── module/
│
├── presentation/
│   ├── builders/
│   ├── pages/
│   ├── renderer/
│   ├── widgets/
📌 7. MODULE SYSTEM (OS CORE RULE)

Every module MUST:

class ModuleNameModule extends AppModule
✅ Every module MUST declare:
routes
permissions
widgets
metadata
lazy loading
dashboard exposure
✅ FINAL MODULE STRUCTURE
features/module_name/
├── application/
├── domain/
├── infrastructure/
├── presentation/
├── module/
└── config/
❌ FORBIDDEN IN feature modules
Scaffold
AppBar
Drawer
BottomNavigationBar

Allowed ONLY in:

core/shell/
📌 8. SYSTEM FLOW (ENTRY POINT)
main.dart
    ↓
Context Engine
    ↓
Unified App Shell
    ↓
Core Router
    ↓
Dashboard Engine
    ↓
module_runtime_adapter
    ↓
system/module_control
    ↓
system/registry
    ↓
Feature Modules
📌 9. BACKEND AUTHORITY RULE

Backend controls:

module availability
permissions
activation
feature flags
governance

Flutter ONLY:

consumes runtime state
renders UI
📌 10. CONTEXT ENGINE RULE

All modules MUST resolve:

user context
entity context
farm context
role context
session context

❌ No hardcoded assumptions allowed.

📌 11. RIVERPOD RULE

Strict flow:

UI
→ Provider
→ Controller/Application
→ Repository
→ Service
→ Backend
❌ FORBIDDEN
UI → Supabase
logic inside widgets
FutureBuilder business orchestration
providers owning business logic

Providers are:

passive state exposure layers

📌 12. DASHBOARD ENGINE PIPELINE
system.registry
        ↓
system.module_control
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
📌 13. COMPOSITION RULE
✅ Composition Engine

Responsible for:

composition graph generation
zone assignment
node ordering
snapshot creation
❌ Composition Engine MUST NEVER
render widgets
own permissions
access Supabase
define modules
📌 14. RENDERER RULE
✅ Renderer Responsibilities
paint UI
incremental rendering
widget caching
rebuild isolation
❌ Renderer MUST NEVER
decide layouts
load modules
perform governance
fetch backend data
📌 15. REACTIVE ENGINE RULE

Dashboard engine is fully reactive.

Triggers include:

module activation
role changes
entity switching
feature flag updates
realtime backend sync
📌 16. PERFORMANCE RULES

Mandatory:

single-trip queries
registry caching only
lazy loading
pagination
incremental rendering
snapshot diffing
bounded caches
deterministic composition
❌ FORBIDDEN
duplicate registry systems
full dashboard rebuilds
unbounded memory maps
duplicated layout logic
recreating services in build()
📌 17. STORAGE RULE
media/
├── images/
├── videos/
├── documents/
└── thumbnails/

Rules:

client compression mandatory
server optimization mandatory
thumbnails-first rendering
no raw uploads
controlled egress only
📌 18. UI RULE

Mandatory:

responsive design
LayoutBuilder usage
mobile/tablet/desktop support
❌ FORBIDDEN
Scaffold inside feature modules
business logic in UI
module governance in presentation
📌 19. ENGINEERING GOLDEN RULE
system layer decides IF modules exist
dashboard engine decides HOW runtime UI is composed
renderer decides HOW UI is painted
diff engine decides WHAT changed
Flutter renders
backend governs