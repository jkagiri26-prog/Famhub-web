MASTER DEVELOPMENT RULEBOOK (FAMHUB v3.0 — FINAL STRUCTURE LOCKED)

This document is the single source of truth for all AI-assisted development in FAMHUB.

It applies to:

ChatGPT
VS Code AI assistants
Continue
Cline
Claude
OpenRouter agents
Local models (Ollama, DeepSeek, CodeLlama, etc.)
Any future engineering system
⚠️ STATUS

This is NOT guidance

These are strict engineering constraints

All AI systems MUST comply before generating code.

1. CORE IDENTITY
Project: FAMHUB

A unified:

AgriTech + Agri-Finance + Commerce + Governance Operating System (AOS)
Users
Farmers
Livestock keepers
Agrovet dealers
Traders
Buyers
Cooperatives
Processors
Input manufacturers
Extension officers
Financial institutions
Insurance providers
Carbon credit stakeholders
System Scope

Production → Operations → Traceability → Marketplace → Commerce → Finance → Insurance → Analytics → Governance

NOT A PRODUCT TYPE

FAMHUB is NOT:

marketplace app
farm tracker
SaaS dashboard

It is:

🧠 Agricultural Operating System (AOS)
2. CORE STACK
Frontend
Flutter
Dart
Riverpod
GoRouter
Responsive App Shell
Unified Dashboard Host
Registry-driven modules
Backend
Supabase (PostgreSQL)
Row Level Security (RLS)
Edge Functions
Event-driven architecture
Context Engine
Media pipeline system
Infrastructure
Single media bucket system
Dynamic module loader
Registry caching system
Offline-first sync layer
Remote config system
3. ABSOLUTE NON-NEGOTIABLE RULES
RULE A — NO SCAFFOLD RULE

Feature modules MUST NOT contain:

Scaffold
AppBar
Drawer
BottomNavigationBar

Allowed ONLY in:

Core Shell
Unified App Shell

Modules render pure content only

RULE B — IDENTITY IS NEVER PASSED FROM FRONTEND

Frontend MUST NEVER pass:

user_id
owner_id
identity fields

Identity must be resolved server-side using:

core.auth_user_id()

Enforced via RLS.

RULE C — NO DIRECT SUPABASE ACCESS FROM UI
Forbidden:

UI → Supabase

Required:

UI → Provider → Controller → Repository → Service → Backend

No exceptions.

RULE D — FULL FILE OUTPUT ONLY

AI MUST always return:

full file code
exact file paths
registry updates
integration notes

No partial snippets unless explicitly requested.

RULE E — SCHEMA-FIRST DEVELOPMENT

Database schema is authoritative.

Never:

invent fields
guess schema
bypass backend structure
4. FINAL LOCKED PROJECT STRUCTURE (v3.0)
lib/
│
├── main.dart
│
├── app/
│   └── (minimal bootstrap only)
│
├── core/
│   │
│   ├── shell/
│   │   ├── app_shell_context.dart
│   │   └── unified_app_shell.dart
│   │
│   ├── router/
│   │   ├── app_router.dart
│   │   ├── navigation_service.dart
│   │   ├── route_guards.dart
│   │   ├── route_names.dart
│   │   └── route_notifier.dart
│   │
│   ├── config/
│   │   ├── remote_config/
│   │   ├── app_config.dart
│   │   ├── env_config.dart
│   │   └── supabase_config.dart
│   │
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_icons.dart
│   │   ├── app_sizes.dart
│   │   └── app_strings.dart
│   │
│   ├── context_engine/
│   │   ├── controllers/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── services/
│   │   └── context_provider.dart
│   │
│   ├── database/
│   │   ├── database_helper.dart
│   │   ├── query_builder.dart
│   │   ├── realtime_service.dart
│   │   └── storage_service.dart
│   │
│   ├── guards/
│   │   ├── auth_guard.dart
│   │   ├── profile_guard.dart
│   │   ├── role_guard.dart
│   │   └── guest_guard.dart
│   │
│   ├── navigation/
│   │   ├── bottom_nav.dart
│   │   ├── side_nav.dart
│   │   ├── nav_config.dart
│   │   └── nav_item.dart
│   │
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── carbon_provider.dart
│   │   ├── location_provider.dart
│   │   ├── module_provider.dart
│   │   ├── notification_provider.dart
│   │   ├── theme_provider.dart
│   │   └── user_provider.dart
│   │
│   ├── services/
│   │   ├── media/
│   │   ├── offline/
│   │   ├── api_services.dart
│   │   ├── auth_services.dart
│   │   ├── location_services.dart
│   │   ├── module_service.dart
│   │   ├── modules_registry.dart
│   │   ├── notification_services.dart
│   │   ├── permission_services.dart
│   │   ├── storage_services.dart
│   │   └── supabase_service.dart
│   │
│   └── theme/
│       ├── app_theme.dart
│       ├── dark_theme.dart
│       ├── light_theme.dart
│       └── text_styles.dart
│
├── system/
│   ├── module_contract.dart
│   ├── module_loader.dart
│   ├── module_registry.dart
│   ├── module.dart
│   └── governance/
│
├── shared/
│   ├── widgets/
│   ├── layouts/
│   ├── cards/
│   ├── headers/
│   └── reusable UI only
│
├── features/
│   └── module_name/
│       ├── application/
│       ├── domain/
│       ├── infrastructure/
│       ├── presentation/
│       └── module.dart
│
└── ai/
    └── optional intelligence layer
🧠 CRITICAL ARCHITECTURE DECISION (LOCKED)
APP LAYER

app/ = minimal bootstrap only

Contains:

main wiring
startup initialization only

It does NOT contain:

shell
router
business logic
CORE LAYER

core/ = infrastructure backbone

Contains:

shell
router
services
providers
guards
context engine
database
theme
navigation
SYSTEM LAYER

system/ = governance + module system

Contains:

module loader
registry
module contracts
permissions
activation rules
FEATURES LAYER

features/ = business modules only

Contains:

marketplace
farm_management
finance
logistics
profile
dashboard
etc.
SHARED LAYER

shared/ = reusable UI only

Contains:

reusable widgets
cards
layouts
headers
responsive wrappers

No business logic allowed.

5. SELF-REGISTERING MODULE RULE

Every module MUST implement:

class ModuleNameModule extends AppModule

Must register:

routes
permissions
dashboard widgets
metadata
lazy loading

No hardcoded navigation.

6. UNIFIED DASHBOARD RULE

Dashboard is a FEATURE MODULE

NOT core
NOT system

Everything registers into:

UnifiedDashboardHost

Dashboard must be:

dynamic
role-aware
context-aware
registry-driven

AI MUST NEVER hardcode dashboard widgets.

7. CONTEXT ENGINE RULE

All modules MUST resolve:

User context
Entity context
Farm context
Business context
Role context

No hardcoding allowed.

8. RIVERPOD ARCHITECTURE RULE

Strict flow:

UI → Provider → Controller → Repository → Service → Backend

Forbidden:

logic inside UI
direct Supabase calls
FutureBuilder architecture for business systems
9. PERFORMANCE PROTOCOL

Mandatory:

single-trip queries
pagination
lazy loading
registry caching
payload minimization
server-side aggregation
low-bandwidth optimization
no duplicate fetches
10. STORAGE & MEDIA GOVERNANCE

Bucket:

media/

Structure:

images/
videos/
documents/
thumbnails/

Rules:

client compression mandatory
server optimization required
thumbnails-first loading
no raw uploads
strict cost control
11. RESPONSIVE UI RULE

All UI must support:

mobile
tablet
desktop

Using:

LayoutBuilder
ResponsiveWrapperWidget

No fixed-device assumptions.

12. NAMING CONVENTIONS
files → snake_case
classes → PascalCase
methods → camelCase
database → snake_case
13. MODULE SUBMISSION PROTOCOL

Every module must include:

full structure
full codebase
provider + repository + UI
registry integration
permissions mapping
dashboard widget registration
backend mapping
performance notes
security validation

No partial delivery.

14. AI ENGINEERING BEHAVIOR

AI must:

prefer correctness over speed
enforce architecture consistency
refuse unsafe shortcuts
never invent schema
never bypass rules
never duplicate layers
prefer alignment over redesign
15. FINAL PRINCIPLE

FAMHUB is built for:

production systems
real farmers
real money flow
real governance
real scale

Every decision must survive:

scale
cost pressure
security review
real users
institutional adoption