AMHUB DASHBOARD AI ASSISTANT INSTRUCTIONS (v1)
📌 1. CORE RULE

The dashboard system is layered OS architecture.
Never collapse layers or bypass them.

Flow MUST always be:
Supabase
  ↓
Repository (infrastructure)
  ↓
Provider (Riverpod state)
  ↓
Binding Service (layout decision logic)
  ↓
Preset Engine (layout definitions)
  ↓
Renderer Service (widget → zones)
  ↓
Composition Engine (UI structure)
  ↓
UI (Bind Engine / Host)
📌 2. STRICT LAYER RESPONSIBILITIES
🔹 Domain
Models only
NO logic
NO Supabase
NO Flutter widgets
🔹 Infrastructure
Supabase access
Repositories
Widget resolvers
Cache systems
🔹 Application
Business logic
Binding service
Composition engine
Layout decision logic
🔹 Presentation
BindEngine / Host widgets
UI composition only
NO business logic
📌 3. CRITICAL RULES (DO NOT BREAK)
❌ Never do:
Direct Supabase calls in UI
Layout logic inside widgets
Mixing Map<String,dynamic> with domain models
Duplicating renderer + composer logic
Skipping binding layer
Hardcoding layout selection in UI
✅ Always do:
Use DashboardLayoutBindingService for layout selection
Use DashboardLayoutPresetEngine for preset resolution
Use DashboardRendererService for widget → zone mapping
Use DashboardCompositionEngine for final UI structure
📌 4. LAYOUT SYSTEM RULE

Layout selection is ALWAYS:

Entity override
   ↓
Role override
   ↓
Module override
   ↓
Device fallback

Handled ONLY in:

DashboardLayoutBindingService
📌 5. DATA MODEL RULE

Use ONLY domain models:

DashboardDescriptor
DashboardLayoutBindingRule
DashboardLayoutPreset
DashboardZoneData

❌ Do NOT use raw Map<String, dynamic> in application layer.

📌 6. RIVERPOD RULE
Providers ONLY expose state
Providers do NOT contain logic
No Supabase inside UI
No business logic inside providers
📌 7. PERFORMANCE RULES
Renderer may cache widgets
Repository may cache backend data
Binding service must remain stateless
Composition engine must remain pure
📌 8. EXTENSION RULE

If adding new feature:

ALWAYS ask:
Is it data? → infrastructure
Is it logic? → application
Is it UI? → presentation
Is it structure decision? → binding service
📌 9. DASHBOARD GUARANTEE

Every dashboard must support:

multi-device layouts
role-based layouts
entity-specific overrides
real-time descriptor updates
preset-based UI switching
📌 10. GOLDEN RULE

“Renderer builds WHAT to show
Composer builds HOW to show
Binding decides WHICH layout to use”