# FAMHUB SDK Guide

**For feature developers — not framework developers.**

This guide teaches you how to use the FAMHUB SDK to build features without
understanding the runtime internals (engines, providers, bridges, repositories).

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Navigation](#navigation)
3. [Capabilities](#capabilities)
4. [Policy](#policy)
5. [Workspace](#workspace)
6. [Organization](#organization)
7. [Access Control](#access-control)
8. [Notifications](#notifications)
9. [Workflow](#workflow)
10. [Dashboard](#dashboard)
11. [Shell & Layout](#shell--layout)
12. [Spatial](#spatial)
13. [AI Context](#ai-context)

---

## Getting Started

### Install

The SDK is built into the app — no additional package needed.

### Access the SDK

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/sdk/famhub_sdk.dart';

// Inside any Riverpod widget or provider:
final sdk = ref.read(famhubSdkProvider);

// Or watch it for reactivity (though SDK is a stateless facade):
final sdk = ref.watch(famhubSdkProvider);
```

### What the SDK is

The SDK is a **facade** — it delegates to the runtime without exposing it.
Think of it as a remote control for the application:

```
You (Feature Module)
    │
    ▼
FamhubSdk  ←  THE ONLY public API
    │
    ▼
Internal runtime  ←  Hidden from you
```

### What the SDK is NOT

The SDK does **not** contain:
- Business logic
- Database queries
- Network calls
- UI components
- Internal providers/engines

All of that lives beneath the SDK and is intentionally hidden.

---

## Navigation

Open modules, navigate between pages, manage route history.

### Go to a module

```dart
sdk.navigation.openModule(context, 'marketplace');
sdk.navigation.openModule(context, 'farm');
sdk.navigation.openModule(context, 'inventory');
```

### Go to a specific route

```dart
sdk.navigation.go(context, '/farm/detail/abc-123');
sdk.navigation.push(context, '/marketplace/new-listing');
```

### Open named destinations

```dart
sdk.navigation.openDashboard(context);
sdk.navigation.openSettings(context);
sdk.navigation.openNotifications(context);
sdk.navigation.openSearch(context);
sdk.navigation.openHome(context);
sdk.navigation.openAiAssistant(context);
```

### Navigation stack control

```dart
sdk.navigation.pop(context);
sdk.navigation.popWithResult(context, result);
sdk.navigation.replace(context, '/new-route');
```

---

## Capabilities

Check what the current user/organization is allowed to do.

### Basic checks

```dart
// Check if a capability is enabled
if (sdk.capabilities.has(Capabilities.marketplaceListings)) {
  // Show marketplace listings
}

// Check capability level (0 = disabled, higher = more access)
final level = sdk.capabilities.level(Capabilities.workflowExecution);
if (level >= 3) {
  // Allow advanced workflows
}
```

### Composite checks

```dart
// ALL capabilities required
if (sdk.capabilities.hasAll([
  Capabilities.marketplaceListings,
  Capabilities.workflowExecution,
])) {
  // Full access
}

// ANY capability required
if (sdk.capabilities.hasAny([
  Capabilities.basicView,
  Capabilities.premiumView,
])) {
  // At least basic access
}
```

### Specialized checks

```dart
sdk.capabilities.canExecute(Capabilities.workflowExecution);
sdk.capabilities.canAutomate(Capabilities.workflowExecution);
sdk.capabilities.canRender(Capabilities.marketplaceListings);
```

---

## Policy

Read location-based policy rules.

```dart
// Boolean check
if (sdk.policy.isAllowed(Policies.workflowExecution)) {
  // Allowed in this location
}

// Numeric limits
final maxImages = sdk.policy.number(Policies.maxImageUpload);
final maxListings = sdk.policy.number(Policies.maxActiveListings);

// String/text values
final region = sdk.policy.text(Policies.regionRestriction);

// List values
final restrictedSpecies = sdk.policy.list(Policies.restrictedSpecies);

// Check if a rule exists
if (sdk.policy.hasRule(Policies.customRule)) {
  final value = sdk.policy.value(Policies.customRule);
}
```

---

## Workspace

Manage tabs, layouts, and sidebar state.

### Tab management

```dart
// Open a new tab
sdk.workspace.openTab(WorkspaceTab(
  id: 'tab-123',
  moduleKey: 'marketplace',
  label: 'Marketplace',
));

// Close a tab
sdk.workspace.closeTab('tab-123');

// Focus a tab
sdk.workspace.focusTab('tab-456');

// Pin a tab (survives workspace clearing)
sdk.workspace.pinTab('tab-pinned-1');

// Reopen the most recently closed tab
sdk.workspace.openRecent();
```

### Workspace state

```dart
// Get the active module
final moduleKey = sdk.workspace.currentModule();

// Get the active tab
final tab = sdk.workspace.activeTab();

// Get all open tabs
final allTabs = sdk.workspace.openTabs();

// Check if any tabs are open
if (sdk.workspace.hasTabs()) { ... }

// Get current workspace ID
final wsId = sdk.workspace.currentWorkspaceId();
```

### Layout control

```dart
sdk.workspace.setWindowMode(WindowMode.maximized);
sdk.workspace.setShellMode(ShellLayoutMode.focus);

final mode = sdk.workspace.windowMode();
final shellMode = sdk.workspace.shellMode();
```

### Sidebar

```dart
final expanded = sdk.workspace.sidebarExpanded();
final panelVisible = sdk.workspace.secondaryPanelVisible();
```

---

## Organization

Access the current organization context.

```dart
// Basic info
final orgId = sdk.organization.organizationId();
final orgName = sdk.organization.organizationName();
final orgType = sdk.organization.organizationType();

// Status checks
if (sdk.organization.isActive()) { ... }
if (sdk.organization.isVerified()) { ... }
if (sdk.organization.isOnboarded()) { ... }

// Type checks
if (sdk.organization.isFarmer()) { ... }
if (sdk.organization.isCooperative()) { ... }
if (sdk.organization.isEnterprise()) { ... }
if (sdk.organization.isGovernment()) { ... }

// Switch organization
await sdk.organization.switchOrganization('org-456');
await sdk.organization.refreshOrganization();
```

---

## Access Control

Check if the user can perform actions in modules.

### Common checks

```dart
// Navigation
if (sdk.access.canNavigate('marketplace')) { ... }
if (sdk.access.canAccess('marketplace', 'listings')) { ... }

// CRUD
if (sdk.access.canCreate('marketplace')) { ... }
if (sdk.access.canEdit('marketplace')) { ... }
if (sdk.access.canDelete('marketplace')) { ... }

// Special actions
if (sdk.access.canApprove('workflow')) { ... }
if (sdk.access.canPurchase('marketplace')) { ... }
if (sdk.access.canExport('reports')) { ... }
if (sdk.access.canUpload('documents')) { ... }

// AI features
if (sdk.access.canUseAI('analytics')) { ... }
```

### Detailed decisions

```dart
final decision = sdk.access.decision('marketplace', 'navigate');
if (decision.allowed) {
  // Proceed
} else {
  showError(decision.reason);
}

final reason = sdk.access.denyReason('marketplace', 'delete');
if (reason != null) {
  showError('Cannot delete: $reason');
}
```

---

## Notifications

Show alerts and track unread counts.

```dart
// Quick notifications
sdk.notifications.showSuccess('Farm created successfully!');
sdk.notifications.showError('Failed to save changes.');
sdk.notifications.showWarning('License expires in 7 days.');
sdk.notifications.showInfo('New update available.');

// Custom notification
sdk.notifications.show(
  title: 'Order Received',
  body: 'New order #1234 from John Doe',
  id: 1234,
  payload: 'order_detail/1234',
);

// Badge count
final count = sdk.notifications.badgeCount();
sdk.notifications.resetBadge();
sdk.notifications.incrementBadge();
sdk.notifications.setBadgeCount(5);
```

---

## Workflow

Execute and manage business workflows.

```dart
// Start a workflow
final state = sdk.workflow.execute('module_publish');

// Check status
final status = sdk.workflow.status('workflow-abc');
if (status != null && status.isActive) {
  // Workflow is running
}

// Complete a step
sdk.workflow.completeStep(
  'module_publish',
  'validation',
  result: {'approved': true},
);

// Cancel a workflow
sdk.workflow.cancel('module_publish');

// Check if active
if (sdk.workflow.isActive('module_publish')) { ... }

// Get available steps
final steps = sdk.workflow.availableSteps('module_publish');
```

---

## Dashboard

Access dashboard composition — widgets, modules, and layout descriptors.

```dart
// Get all dashboard widgets
final widgets = await sdk.dashboard.widgets();

// Get quick actions
final actions = await sdk.dashboard.quickActions();

// Get home widgets
final homeWidgets = await sdk.dashboard.homeWidgets();
final homeByType = await sdk.dashboard.homeWidgetsByType();

// Get visible cards by section
final cards = await sdk.dashboard.visibleCards();

// Get enabled runtime modules
final modules = await sdk.dashboard.enabledModules();

// Trigger a refresh
await sdk.dashboard.refresh();
```

---

## Shell & Layout

Control the shell appearance and behavior.

```dart
// Sidebar
sdk.shell.toggleSidebar();
sdk.shell.setSidebarExpanded(true);
final isExpanded = sdk.shell.sidebarExpanded();

// Theme
sdk.shell.setThemeMode(ThemeMode.dark);
sdk.shell.toggleTheme();
final currentMode = sdk.shell.themeMode();

// Brand info
final brand = sdk.shell.brandName();
final tagline = sdk.shell.brandTagline();
final theme = sdk.shell.theme();
```

---

## Spatial

Manage spatial assets, boundaries, GPS capture, and overlap analysis.

### Access via SDK

```dart
final sdk = ref.read(famhubSdkProvider);
final spatial = sdk.spatial;
```

### Current Asset

```dart
// Get the currently selected spatial asset
final asset = spatial.currentAsset();
print(asset?.name);     // "Field 3A"
print(asset?.assetType); // "field"
print(asset?.areaHa);    // 12.5

// Select a spatial asset
await spatial.selectAsset(asset);

// Get child assets (e.g., blocks within a field)
final children = await spatial.childAssets(parentId);

// Get all assets for an entity
final allAssets = await spatial.assets(entityId);

// Clear the current selection
spatial.clearAsset();

// Check if an asset is selected
if (spatial.hasSelectedAsset()) { ... }
```

### Boundary Management

```dart
// Get the current boundary
final boundary = spatial.boundary();
if (boundary != null) {
  print(boundary.accuracyLevel); // 'gps', 'survey', 'satellite'
}

// Check if the current asset has a boundary
if (spatial.hasBoundary()) { ... }

// Get the boundary ID
final id = spatial.boundaryId();

// Upload a new boundary
await spatial.uploadBoundary(
  geometry: {
    'type': 'Polygon',
    'coordinates': [[...]],
  },
  accuracyLevel: 'gps',
);
```

### GPS Capture

```dart
// Start a capture session
final session = await spatial.capture(mode: 'manual');

// Add GPS points
await spatial.addPoint(
  latitude: -25.345,
  longitude: 28.123,
  accuracyMeters: 3.5,
);

// Get recorded points
final points = spatial.points();

// Check capture status
if (spatial.hasCapture()) { ... }
if (spatial.isCaptureComplete()) { ... }

// Finish or cancel
await spatial.finishCapture();
await spatial.cancelCapture();
```

### Overlap Detection

```dart
// Check for overlaps
if (spatial.hasOverlap()) { ... }

// Get overlaps
final overlaps = spatial.overlaps();

// Detect overlaps (triggers backend PostGIS analysis)
final detected = await spatial.detectOverlaps();
```

### Spatial Analytics

```dart
// Calculate area (client-side approximation)
final areaHa = spatial.area();

// Calculate perimeter (client-side approximation)
final perimeterM = spatial.perimeter();

// Get backend-calculated area (source of truth)
final backendArea = spatial.areaHa();
```

### AI Context Integration

The AI context snapshot now includes spatial data:

```dart
final ctx = sdk.ai.snapshot();
print(ctx.selectedSpatialAsset?.name); // Current farm/field
print(ctx.area);                        // Area in hectares
print(ctx.boundaryId);                  // Current boundary ID
print(ctx.captureSession);              // Active capture session
print(ctx.assetType);                   // 'farm', 'field', 'block'
print(ctx.parentAsset);                 // Parent asset ID
```

---

## AI Context

Get a snapshot of the current app state for AI features.

```dart
// Complete context snapshot
final ctx = sdk.ai.snapshot();
print(ctx.organization.organizationName);
print(ctx.currentModule);
print(ctx.activeTab?.label);

// Individual queries
final org = sdk.ai.currentOrganization();
final ws = sdk.ai.currentWorkspace();
final module = sdk.ai.currentModule();
final tab = sdk.ai.activeTab();
final entityId = sdk.ai.selectedEntity();
final history = sdk.ai.navigationHistory();

// Spatial context
final spatial = sdk.ai.selectedSpatialAsset();
final area = sdk.ai.area();
final boundaryId = sdk.ai.boundaryId();
```

---

## Best Practices

### 1. Always use the SDK, never internal providers

```dart
// ✅ CORRECT — use the SDK
final sdk = ref.read(famhubSdkProvider);
sdk.workspace.openTab(tab);

// ❌ WRONG — bypassing the SDK
final notifier = ref.read(activeWorkspaceProvider.notifier);
notifier.openTab(tab);
```

### 2. Keep SDK calls at the boundary

Fetch data through the SDK in your provider/widget boundary,
then use the data in your business logic.

### 3. Don't mix SDK and internal access

If you use the SDK for navigation, use it for everything.
Don't mix `sdk.navigation.go()` with direct `context.go()`.

### 4. Test through the SDK

Write integration tests against the SDK facade, not internal engines.
This validates the public contract.

### 5. Read the SDK version

```dart
import 'package:famhub_app/core/sdk/api/sdk_version.dart';

if (SdkVersion.isCompatibleWith('1.0.0')) {
  // Use 1.0.0 features safely
}
```

---

## Quick Reference

| Domain | SDK Object | Example |
|--------|-----------|---------|
| Navigation | `sdk.navigation` | `sdk.navigation.openModule(context, 'farm')` |
| Capabilities | `sdk.capabilities` | `sdk.capabilities.has(Capabilities.marketplaceListings)` |
| Policy | `sdk.policy` | `sdk.policy.isAllowed(Policies.workflowExecution)` |
| Workspace | `sdk.workspace` | `sdk.workspace.openTab(myTab)` |
| Organization | `sdk.organization` | `sdk.organization.organizationId()` |
| Access | `sdk.access` | `sdk.access.canAccess('marketplace', 'listings')` |
| Notifications | `sdk.notifications` | `sdk.notifications.showSuccess('Done!')` |
| Workflow | `sdk.workflow` | `sdk.workflow.execute('module_publish')` |
| Dashboard | `sdk.dashboard` | `final widgets = await sdk.dashboard.widgets()` |
| Shell | `sdk.shell` | `sdk.shell.toggleSidebar()` |
| Spatial | `sdk.spatial` | `sdk.spatial.selectAsset(asset)` |
| AI Context | `sdk.ai` | `final ctx = sdk.ai.snapshot()` |
