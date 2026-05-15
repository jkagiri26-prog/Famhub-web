---
description: FEATURE MODULE REFERENCE POLICY
---

# Feature Module Reference Policy

The OFFICIAL source of truth is:

FAMHUB OS v1.0 Locked Architecture

NOT any individual module.

---

## Current Status

`farm_management` is the most advanced operational module
and is used as a temporary alignment reference for:

- deep workflow modules
- multi-page operational systems
- complex provider/repository flows
- dashboard-integrated business modules

However:

`farm_management` is still under alignment and cleanup.

It is NOT yet the final structural authority.

Do NOT blindly copy old patterns from it.

Always validate against:

FAMHUB OS v1.0 architecture first.

---

## Final Rule

Priority order:

1. FAMHUB OS v1.0 Locked Architecture (highest authority)
2. Shared system patterns (core/system/shared)
3. Aligned feature modules
4. farm_management (only where already aligned)

Never reverse this order.

---

## Important

Do NOT use farm_management as the platform entry reference.

System entry remains:

main.dart
→ Context Provider
→ Unified App Shell
→ Core Router
→ UnifiedDashboardHost
→ ModuleService
→ system.modules
→ Feature Modules

Dashboard is the OS home.

Backend governs modules.

Flutter renders modules.

---

## Safe Rule

Use farm_management for:

workflow patterns

Do NOT use farm_management for:

architecture authority