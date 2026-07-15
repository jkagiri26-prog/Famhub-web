# Capability Framework Integration Guide

## Overview

The Capability Framework is a first-class runtime layer that determines **what operational abilities an organization can execute**. It is NOT a subscription system, NOT a user-role system, and NOT a feature-flag system.

### Core Principle

```
Instead of:                    Use:
  if (enterprise) → show X       engine.hasCapability(Capabilities.workflowExecution)
  if (aggregator) → show Y       engine.getCapabilityLevel(Capabilities.inventoryStock)
  if (cooperative) → show Z      engine.canExecute(Capabilities.marketplaceOrders)
```

**Every behavioral difference must originate from the Capability Framework.**

---

## Architecture

```
Organization
    ↓
CapabilityProfile (organization's assigned capabilities + levels)
    ↓
CapabilityEngine (pure evaluation engine)
    ↓
RuntimeCompositionEngine + CapabilityCompositionBridge
    ↓
Navigation → Dashboard → Modules → Workflows
```

### Key Components

| Component | Location | Responsibility |
|-----------|----------|----------------|
| `Capability` | `core/capabilities/domain/capability.dart` | Pure identifier + description |
| `CapabilityLevel` | `core/capabilities/domain/capability_level.dart` | Level definitions |
| `CapabilityProfile` | `core/capabilities/domain/capability_profile.dart` | Organization's capability state |
| `CapabilityRegistry` | `core/capabilities/registry/capability_registry.dart` | Static catalog of all capabilities |
| `CapabilityEngine` | `core/capabilities/application/capability_engine.dart` | Pure evaluation logic |
| `CapabilityCompositionBridge` | `core/capabilities/composition/` | Pipeline integration |
| Providers | `core/capabilities/application/` | Riverpod runtime bridge |

---

## How to Use Capabilities

### 1. Checking if a Capability is Available

```dart
// In any Riverpod consumer
final canListInMarketplace = ref.watch(
  hasCapabilityProvider(Capabilities.marketplaceListings),
);

if (canListInMarketplace) {
  // Show marketplace listing UI
}
```

### 2. Checking Capability Level

```dart
final workflowLevel = ref.watch(
  capabilityLevelProvider(Capabilities.workflowExecution),
);

// Level 3 = Activity + Inventory + Financials
if (workflowLevel >= 3) {
  // Show financial recording step
}
```

### 3. Semantic Checks

```dart
final engine = ref.watch(capabilityEngineProvider);

// Can this workflow stage execute?
if (engine?.canExecute(Capabilities.inventoryStock) == true) {
  // Include inventory stage
}

// Can this component render?
if (engine?.canRender(Capabilities.financeRecording) == true) {
  // Render financial summary widget
}

// Can automation run?
if (engine?.canAutomate(Capabilities.workflowExecution) == true) {
  // Enable automation features
}
```

### 4. Direct CapabilityEngine Access

```dart
final engine = ref.read(capabilityEngineProvider);
if (engine != null && engine.hasCapability('inventory.stock')) {
  // Handle inventory operation
}
```

---

## How to Declare Module Capabilities

When creating a new module, declare its capability requirements in `bootstrap/capability_bootstrap.dart`:

```dart
registerModuleCapabilities(
  'your_module_key',
  requiredCapabilities: [
    Capabilities.yourCapability.id,
  ],
  widgetCapabilities: {
    'specific_widget_key': [
      Capabilities.someCapability.id,
      Capabilities.anotherCapability.id,
    ],
    'another_widget_key': [
      Capabilities.yetAnother.id,
    ],
  },
);
```

### Rules for Module Capability Declarations

1. **Never hide an entire module when only one feature is unavailable.** Only hide or disable the specific affected widget or feature.

2. **`requiredCapabilities`** should only be used when the module is completely non-functional without the capability.

3. **`widgetCapabilities`** should be used for individual features/widgets within a module.

4. **Use the `Capabilities` constants** (e.g., `Capabilities.inventoryStock`) — never hardcode capability ID strings.

---

## How to Define New Capabilities

1. Add a new constant in `core/capabilities/domain/capability.dart`:

```dart
static const yourNewCapability = Capability(
  id: 'yourdomain.youroperation',
  name: 'Your Operation',
  description: 'Description of what this enables',
  domain: 'yourdomain',
);
```

2. Add it to the `all` list in the same file.

3. Register it in `core/capabilities/registry/capability_registry.dart`:

```dart
register(CapabilityRegistration(
  capability: Capabilities.yourNewCapability,
  levels: CapabilityLevelPresets.binaryLevels,
  defaultLevel: 1,
));
```

4. Declare module requirements in `bootstrap/capability_bootstrap.dart`.

---

## Workflow Integration

The `DynamicActivityWorkflowService` must use capability checks instead of organization-type branching:

```dart
// ❌ BAD: Organization-type check
if (organizationType == 'enterprise') {
  // Show automation stage
}

// ✅ GOOD: Capability check
final engine = ref.read(capabilityEngineProvider);
if (engine?.canAutomate(Capabilities.workflowExecution) == true) {
  // Show automation stage
}
```

Use `CapabilityWorkflowStage` for workflow stage definitions:

```dart
final stages = [
  CapabilityWorkflowStage(
    stageKey: 'activity',
    displayName: 'Record Activity',
    requiredCapabilityId: Capabilities.workflowExecution.id,
    isOptional: false,
  ),
  CapabilityWorkflowStage(
    stageKey: 'inventory',
    displayName: 'Link Inventory',
    requiredCapabilityId: Capabilities.inventoryStock.id,
    isOptional: true,
  ),
  CapabilityWorkflowStage(
    stageKey: 'financials',
    displayName: 'Record Financials',
    requiredCapabilityId: Capabilities.financeRecording.id,
    isOptional: true,
  ),
];

// Filter stages based on available capabilities
final bridge = CapabilityCompositionBridge(engine: engine);
final enabledStages = bridge.getEnabledWorkflowStages(allStages: stages);
```

---

## Dashboard Integration

Dashboard widgets declare required capabilities. The `ResponsiveDashboardRenderer` remains presentation-only — filtering occurs before rendering.

Use the capability-filtered providers:

```dart
// In dashboard renderer
final widgets = ref.watch(
  capabilityFilteredDashboardWidgetsBySectionProvider,
);

// widgets only contains entries for capabilities the org has
```

---

## Navigation Integration

Navigation providers remain unchanged. The `CapabilityEngine` becomes another evaluation input:

```
Nav Item → Runtime Feature Flags → Capability Engine → Context Engine → Visible
```

Use capability-filtered nav providers:

```dart
final sidebarItems = ref.watch(capabilityFilteredSidebarItemsProvider);
final bottomNavItems = ref.watch(capabilityFilteredBottomNavItemsProvider);
final dashNavItems = ref.watch(capabilityFilteredDashboardNavItemsProvider);
```

---

## Future Backend Alignment

The framework is designed so capability profiles can eventually come from the backend.

### Potential Future Tables

```sql
organizations
    id
    name
    type

organization_capabilities
    organization_id
    capability_id
    level
    assigned_at

capabilities
    id
    name
    description
    domain

capability_levels
    capability_id
    level
    name
    description
```

### Migration Path

1. **Stage 3 (Current):** Profile derived from `EntityContext.role` in `capability_profile_provider.dart`
2. **Stage 4:** Replace `_deriveProfileFromContext` with `OrganizationCapabilityRepository.getProfile()`
3. **Stage 5:** Implement real backend repository using Supabase/API

No domain models or application logic need to change — only the provider implementation.

---

## FAQ

### Q: Is this a replacement for RuntimeFeatureFlags?

No. **RuntimeFeatureFlags** control runtime toggleable states (maintenance mode, A/B testing, gradual rollouts). **Capabilities** define permanent operational permissions. Both systems coexist.

### Q: Is this a subscription system?

No. Subscriptions determine *billing tier*. Capabilities determine *operational ability*. An enterprise might have a basic subscription but need full capabilities temporarily.

### Q: Can I use capability checks in widgets?

Yes, use the Riverpod providers (`hasCapabilityProvider`, `capabilityLevelProvider`). But never hardcode capability strings in widgets — always use the `Capabilities` constants.

### Q: What if a capability isn't registered?

`hasCapability()` returns `false` for unregistered capabilities. `getCapabilityLevel()` returns `0` (disabled). Always register new capabilities.

### Q: Can I bypass the Capability Engine?

Don't. The entire purpose of the framework is to have a single source of truth for operational permissions. Bypassing it creates technical debt and makes the system harder to reason about.
