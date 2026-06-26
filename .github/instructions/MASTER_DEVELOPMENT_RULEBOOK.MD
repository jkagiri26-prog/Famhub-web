MASTER DEVELOPMENT RULEBOOK (FAMHUB v4.0 — FINAL OS SPEC)

🧠 Source of Truth: System Architecture (FAMHUB OS)

📌 1. CORE IDENTITY

FAMHUB is a:

🧠 Agricultural Operating System (AOS)

NOT:

marketplace app
farm tracker
SaaS dashboard
System Scope:

Production → Operations → Traceability → Marketplace → Commerce → Finance → Insurance → Analytics → Governance

📌 2. FINAL ARCHITECTURE STRUCTURE (LOCKED)
lib/
├── app/          → bootstrap only
├── core/         → infrastructure backbone
├── features/     → business modules
├── shared/       → reusable UI only
└── system/       → governance + module registry
📌 3. ARCHITECTURE LAYER RESPONSIBILITY
app/
minimal startup only
core/
router
context engine
database services
guards
providers
shell
theme
infrastructure services
features/
business modules only
fully self-contained
OS plug-in components
shared/
reusable UI components only
NO business logic
system/
module registry
module loader
governance rules
permissions + lifecycle
📌 4. MODULE SYSTEM (OS CORE RULE)

Every module MUST:

class ModuleNameModule extends AppModule

Must declare:

routes
permissions
widgets
metadata
lazy loading
dashboard registration
Module Structure
features/module_name/
├── application/
├── domain/
├── infrastructure/
├── presentation/
├── module/
└── config/
❌ Forbidden in features/
Scaffold
AppBar
Drawer
BottomNavigationBar

Allowed ONLY in:

core/shell/
UnifiedDashboardHost
📌 5. SYSTEM FLOW (ENTRY POINT)
main.dart
→ Context Engine
→ Unified App Shell
→ Core Router
→ UnifiedDashboardHost
→ ModuleService
→ system.modules (backend)
→ Feature Modules
📌 6. BACKEND AUTHORITY RULE
Backend controls module availability
Flutter only renders modules
system.modules is source of truth
📌 7. CONTEXT ENGINE RULE

All modules MUST resolve:

user context
entity context
farm context
role context
session context

No hardcoding allowed.

📌 8. RIVERPOD RULE

Strict flow:

UI → Provider → Controller → Repository → Service → Backend

Forbidden:

UI → Supabase
FutureBuilder for business logic
logic inside widgets
📌 9. DASHBOARD ARCHITECTURE (CRITICAL)

Dashboard is a FEATURE MODULE:

features/dashboard/
DASHBOARD PIPELINE
Supabase
→ Repository
→ Provider
→ LayoutBindingResolver
→ UsageTracker (signals only)
→ PresetEngine
→ RendererService
→ CompositionEngine
→ UnifiedDashboardHost
RULES
BindingResolver = ONLY decision authority
UsageTracker = scoring only
Renderer = widget mapping only
Composer = layout structure only
📌 10. LAYOUT RULE

Order is FIXED:

Entity override
Role override
Module override
Device fallback

Only inside LayoutBindingResolver.

📌 11. DATA MODEL RULE

Only domain models allowed:

DashboardDescriptor
DashboardLayoutBindingRule
DashboardLayoutPreset
DashboardZoneData

No Map<String,dynamic> in business logic.

📌 12. PERFORMANCE RULES

Mandatory:

single-trip queries
caching registry only (not heavy data)
pagination
lazy loading
no duplicate fetches
diff-based rendering
📌 13. STORAGE RULE

media/

images/
videos/
documents/
thumbnails/

Rules:

client compression required
server optimization required
thumbnails-first
no raw uploads
📌 14. UI RULE
responsive required (mobile/tablet/desktop)
LayoutBuilder required
no Scaffold in feature modules
📌 15. FINAL ENGINEERING PRINCIPLE

FAMHUB is:

Backend-controlled modular agricultural operating system

Flutter is ONLY a renderer.