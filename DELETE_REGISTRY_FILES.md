# Registry Cleanup - Files to Delete

## Architecture Decision
Removed parallel registry pattern to enforce single-source-of-truth architecture per FAMHUB OS v1.0.

**Rule:** ONE registry system = `lib/system/registry/module_registry.dart`

---

## Files to Delete

### ❌ Priority 1: Delete Immediately

#### `lib/system/registry/dashboard_registry.dart`
**Status:** ✅ No longer referenced  
**Reason:** Duplicate/parallel registry to ModuleRegistry  
**Content:** Static map of dashboard widget builders  
**Impact:** None - all references removed

```
Widget Resolution Flow:
OLD: WidgetResolver → DashboardRegistry → hardcoded widgets
NEW: WidgetResolver → ModuleRegistry → module.dashboardWidgets
```

---

### ❌ Priority 2: Delete (Orphaned Code)

#### `lib/features/farm_management/module/dashboard_widgets_registry.dart`
**Status:** ✅ Orphaned (call removed from FarmManagementRegistry)  
**Reason:** Used to populate the deleted DashboardRegistry  
**Content:** FarmDashboardWidgetsRegistry class that called `DashboardRegistry.register()`  
**Impact:** None - no longer called

```dart
// This file registered widgets to the old DashboardRegistry
// Now superseded by FarmManagementModule.dashboardWidgets list
```

---

## Updated Files (✅ Already Fixed)

### `lib/features/farm_management/module/farm_management_registry.dart`
- Removed import of `dashboard_widgets_registry.dart`
- Removed call to `FarmDashboardWidgetsRegistry.ensureRegistered()`
- Added comment about new architecture

### `lib/core/dashboard/infrastructure/resolvers/dashboard_widget_resolver_service.dart`
- Now delegates to `ModuleRegistry` only
- Queries `module.dashboardWidgets` for widget IDs
- No longer imports or references DashboardRegistry
- Transitional implementation with placeholder widget building

---

## Verification Checklist

Before deleting these files, verify:

- [ ] `grep -r "DashboardRegistry" lib/` returns zero results in code files
- [ ] `grep -r "dashboard_widgets_registry" lib/` returns zero results  
- [ ] `grep -r "FarmDashboardWidgetsRegistry" lib/` returns zero results
- [ ] All dashboard tests pass
- [ ] WidgetResolverService delegates only to ModuleRegistry

---

## Safe Deletion Commands

```bash
# Delete the parallel registry
rm lib/system/registry/dashboard_registry.dart

# Delete orphaned widget registry  
rm lib/features/farm_management/module/dashboard_widgets_registry.dart
```

---

## Architecture After Deletion

```
UNIFIED DASHBOARD SYSTEM
├── ModuleRegistry (✅ SINGLE SOURCE OF TRUTH)
│   ├── FarmManagementModule
│   │   ├── dashboardWidgets: ['farm_kpis', 'farm_activity_timeline', ...]
│   │   └── allowedRoles: ['farmer', 'cooperative', ...]
│   └── [Other modules...]
│
├── WidgetResolverService (✅ DELEGATES TO MODULEREGISTRY)
│   └── Query modules via ModuleRegistry.getAll()
│       └── Check module.dashboardWidgets list
│
└── Dashboard Composer Engine (✅ PRESERVED)
    ├── Layout orchestration
    ├── Zone management
    └── Adaptive rendering

REMOVED:
❌ DashboardRegistry (parallel registry)
❌ FarmDashboardWidgetsRegistry (registry adapter)
❌ Duplicate widget lookup systems
```

---

## Future: AppModule Extension

**Next phase (architecture enhancement):**

Extend `AppModule` with widget builder interface:

```dart
abstract class AppModule {
  // ... existing properties ...
  
  // NEW: Build dashboard widgets by ID
  Widget? buildDashboardWidget(String widgetKey, {
    Map<String, dynamic> config,
    WidgetRef? ref,
  }) => null;  // Override in subclasses
}
```

Then update `WidgetResolverService`:

```dart
for (final module in ModuleRegistry.getAll()) {
  if (module.dashboardWidgets.contains(widgetKey)) {
    final widget = module.buildDashboardWidget(widgetKey, config: config, ref: ref);
    if (widget != null) return widget;
  }
}
```

This will complete the architectural transition.

---

## Validation

After deletion, run:

```bash
# Check for compilation errors
flutter analyze

# Check for broken imports
grep -r "dashboard_registry" lib/

# Run dashboard tests
flutter test test/dashboard_test.dart
```

All should pass with zero references to deleted files.
