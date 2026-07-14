# FAMHUB SDK Migration Guide

**How to migrate between SDK versions.**

This guide documents breaking and non-breaking changes between SDK versions,
with explicit migration steps for feature module developers.

---

## Current Version: 1.0.0

This is the initial stable SDK release. No migration needed yet.

---

## Version 1.0.0 → 1.1.0 (Planned)

### ✅ New Additions (No Migration Needed)

The following will be added in 1.1.0 — no existing code will break:

| Feature | SDK Method | Status |
|---------|-----------|--------|
| Module search | `sdk.navigation.openSearch(context)` | Existing |
| Bulk capability checks | `sdk.capabilities.hasAll()` / `hasAny()` | Existing |
| Workspace reorder | `sdk.workspace.reorderTabs()` | Existing |

### ⚠️ Deprecations (Migration Required for 2.0.0)

The following APIs were **deprecated in 1.0.0** and will be removed in 2.0.0:

| Old API | New API | Migration |
|---------|---------|-----------|
| `sdk.navigation.pop(context)` | `sdk.navigation.popWithResult(context)` | Replace `pop()` with `popWithResult()` |
| `sdk.capabilities.canUseAI(cap)` | `sdk.access.canUseAI(module)` | Move AI checks to access SDK |

#### Migration: NavigationSdk.pop()

**Before:**
```dart
sdk.navigation.pop(context);
```

**After:**
```dart
sdk.navigation.popWithResult(context);
// or if you don't need a result:
if (context.canPop()) context.pop();
```

#### Migration: CapabilitySdk.canUseAI()

**Before:**
```dart
if (sdk.capabilities.canUseAI(Capabilities.aiAnalytics)) { ... }
```

**After:**
```dart
if (sdk.access.canUseAI('analytics')) { ... }
```

---

## Version 1.x.x → 2.0.0 (Breaking Changes)

### ❌ Removals

The following APIs deprecated in 1.x will be **removed**:

- `NavigationSdk.pop()` — use `NavigationSdk.popWithResult()`
- `CapabilitySdk.canUseAI()` — use `AccessSdk.canUseAI()`

### 🔄 Signature Changes

None planned at this time.

### 📦 Package Structure Changes

None planned at this time.

---

## How to Check Compatibility

```dart
import 'package:famhub_app/core/sdk/api/sdk_version.dart';

if (SdkVersion.isCompatibleWith('1.1.0')) {
  // Safe to use 1.1.0 features
} else {
  // Current SDK is older, check migration guide
}
```

---

## Migration Patterns

### Pattern 1: Provider → SDK

If you're currently using internal providers directly, migrate to the SDK:

```dart
// ❌ BEFORE: Direct provider access
final engine = ref.read(capabilityEngineProvider);
final hasAccess = engine.hasCapability('marketplace');

// ✅ AFTER: SDK access
final sdk = ref.read(famhubSdkProvider);
final hasAccess = sdk.capabilities.has(Capabilities.marketplaceListings);
```

### Pattern 2: GoRouter → Navigation SDK

```dart
// ❌ BEFORE: Direct GoRouter
context.go('/marketplace');

// ✅ AFTER: SDK navigation
sdk.navigation.go(context, '/marketplace');
// or better:
sdk.navigation.openModule(context, 'marketplace');
```

### Pattern 3: Direct Repository → SDK

```dart
// ❌ BEFORE: Direct repository
final repo = ref.read(workspaceRepositoryProvider);
await repo.save(workspace);

// ✅ AFTER: SDK delegation
await sdk.workspace.saveWorkspace();
```

---

## Need Help?

If you encounter an API that has no SDK equivalent,
open an issue to request it be added to the public surface.

**Do not** bypass the SDK by importing internal providers directly.
