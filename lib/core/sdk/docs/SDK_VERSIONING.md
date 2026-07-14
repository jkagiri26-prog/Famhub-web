# FAMHUB SDK Versioning Policy

**How the SDK is versioned and what each change means for you.**

---

## Version Format

We follow **Semantic Versioning** (SemVer):

```
MAJOR.MINOR.PATCH
   │     │     │
   │     │     └── Patch — Bug fixes, docs, internal changes (backward-compatible)
   │     └──────── Minor — New features, new methods (backward-compatible)
   └────────────── Major — Breaking API changes (removals, signature changes)
```

**Current version: 1.0.0**

Source of truth: `lib/core/sdk/api/sdk_version.dart`

```dart
class SdkVersion {
  static const int major = 1;
  static const int minor = 0;
  static const int patch = 0;
  static const String current = '1.0.0';
}
```

---

## What Each Change Means

### 🔴 MAJOR (e.g., 1.0.0 → 2.0.0)

**Your code WILL break if you don't update.**

Examples:
- Method removed (after deprecation period)
- Method signature changed (parameters added/removed)
- Return type changed
- Class removed or renamed

**What you must do:**
1. Read the migration guide (`SDK_MIGRATION.md`)
2. Update all affected SDK calls
3. Run tests to verify compatibility

### 🟡 MINOR (e.g., 1.0.0 → 1.1.0)

**Your code will NOT break.**

Examples:
- New method added to an existing SDK class
- New SDK class added
- New optional parameter added

**What you should do:**
- Optionally update to use new features
- No code changes required

### 🟢 PATCH (e.g., 1.0.0 → 1.0.1)

**No changes needed.**

Examples:
- Documentation improvements
- Internal bug fixes (no API surface change)
- Better error messages
- Performance improvements

**What you should do:**
- Nothing — everything still works

---

## Deprecation Policy

Before a method is **removed** in a major version,
it is **deprecated** for at least one minor version.

```
1.0.0  ────  Method is available
1.1.0  ────  Method is @Deprecated with migration hint
2.0.0  ────  Method is removed
```

### Deprecation lifecycle:

1. **Phase 1 (Current minor):** Method works normally
2. **Phase 2 (Next minor):** `@Deprecated` annotation added with migration hint
3. **Phase 3 (Next major):** Method removed — use replacement

### Example:

```dart
// 1.0.0 — Available
@Deprecated('Use canExecute() instead. Will be removed in 2.0.0')
bool hasPermission(String permission) => canExecute(permission);

// 2.0.0 — Removed
// hasPermission no longer exists
```

---

## Version Registry

All version changes are recorded in `lib/core/sdk/api/sdk_version.dart`.

| Version | Date | Type | Changes |
|---------|------|------|---------|
| 1.0.0 | Initial | — | Initial stable SDK release |

---

## CI Enforcement

The SDK API Guard (`sdk_api_guard.dart`) runs in CI to enforce:

1. **No silent changes** — Every version bump must update `sdk_version.dart`
2. **No breaking changes without deprecation** — Removals must follow the deprecation policy
3. **Annotation consistency** — All SDK classes must be annotated `@publicSdk`
4. **No infrastructure leaks** — SDK must not import infrastructure or data layers

---

## For SDK Developers

### When to bump MAJOR

Bump the major version when you:

- Remove a public method or class
- Change a method signature (required parameters, return type)
- Rename a public class or method
- Change the behavior of a method in a non-backward-compatible way

### When to bump MINOR

Bump the minor version when you:

- Add a new method to an existing SDK class
- Add a new SDK class
- Add an optional parameter to an existing method
- Deprecate an existing API

### When to bump PATCH

Bump the patch version when you:

- Fix a bug in an SDK delegation
- Improve documentation
- Add or update tests
- Make performance improvements

### How to add a new SDK method

```dart
// 1. Add the method to the SDK class
@publicSdk
@SdkMethod(version: '1.1.0')  // ← version when this was added
Future<void> newFeature() async { ... }

// 2. Bump the minor version in sdk_version.dart
static const int minor = 1;
static const String current = '1.1.0';
```

### How to deprecate an SDK method

```dart
// 1. Add @Deprecated annotation
@Deprecated('Use newFeature() instead')
@SdkMethod(version: '1.0.0')
void oldFeature() { ... }

// 2. Register in sdk_deprecation.dart
_DeprecatedEntry(
  target: 'CapabilitySdk.oldFeature()',
  message: 'Use newFeature() instead',
  removeIn: '2.0.0',
  since: '1.1.0',
)

// 3. Bump minor version
static const int minor = 1;
static const String current = '1.1.0';
```
