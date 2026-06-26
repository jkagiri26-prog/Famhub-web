# 🧪 White Screen Diagnostic Guide

## How to Use

### Step 1: Run with debugPrint instrumentation

Open `lib/main.dart`. The file already has Phase 1 instrumentation:

```
1. Widgets initialized        ← BEFORE validateEnvironment
2. Supabase initialized       ← AFTER Supabase.initialize succeeds
3. ProviderContainer created  ← AFTER ProviderContainer()
4. runApp()                   ← BEFORE runApp()
5. MyApp.build()              ← INSIDE MyApp.build()
```

**If you see 1–4 but NOT 5:**
- Check the browser/device console for errors
- The crash is in Supabase init, ProviderContainer creation, or the orchestrator/sync engine creation
- Look for `[BOOT] FAILED` messages in the console

**If you see 5:** Continue to Step 2.

---

### Step 2: Bypass Context Engine (Phase 2)

In `lib/main.dart`, inside `MyApp.build()`, **comment out** the PRODUCTION block and **uncomment** Phase 2 block:

```dart
// ==========================================================
// PHASE 2: Bypass Context Engine & Router
// ==========================================================
return const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    body: Center(child: Text('FAMHUB Boot OK')),
  ),
);
```

**If "FAMHUB Boot OK" appears:**
✅ `main()` is good
✅ Routing is not the core issue
❌ Context Engine is the suspect (its `isLoading` gate prevents rendering)

---

### Step 3: Verify Router (Phase 3)

Comment out Phase 2, uncomment Phase 3:

```dart
// ==========================================================
// PHASE 3: Verify Router
// ==========================================================
return MaterialApp(
  debugShowCheckedModeBanner: false,
  home: const Scaffold(
    body: Center(child: Text('Router Bypassed')),
  ),
);
```

**If "Router Bypassed" appears:**
✅ main() works
✅ Router without GoRouter works
❌ GoRouter config may be the issue (redirects, route builders, initialLocation)

---

### Step 4: Verify Dashboard (Phase 4)

Comment out Phase 3, uncomment Phase 4:

```dart
// ==========================================================
// PHASE 4: Verify Dashboard Loading
// ==========================================================
return MaterialApp(
  debugShowCheckedModeBanner: false,
  home: const Scaffold(
    body: Text('Dashboard Loaded'),
  ),
);
```

**If "Dashboard Loaded" appears:**
✅ main() works
✅ Router + Shell works
❌ The dashboard composition/module loading is the issue

---

### Step 5: Check Browser Console (F12)

Open the deployed site and press **F12 → Console**. Look for:

| Error Type | Meaning |
|---|---|
| `TypeError` | Null/undefined access in JS-interop |
| `LateInitializationError` | A `late` variable used before init |
| `NoSuchMethodError` | Method called on null |
| `MissingPluginException` | Platform channel not available (web) |
| `Failed to fetch` | Network issue loading assets |
| `404` | Asset/route not found |
| `GoException` | GoRouter internal error |
| `Assertion failed` | Debug-mode assertion failed |
| `RangeError (index)` | List access out of bounds |

### Step 6: Check Network Tab (F12 → Network)

Look for failed requests:

| Request | If Failed |
|---|---|
| `main.dart.js` | App won't load at all |
| `flutter_bootstrap.js` | Bootstrap fails |
| `AssetManifest.json` | Assets not registered |
| `FontManifest.json` | Fonts missing |
| `SUPABASE_URL` endpoints | Supabase not reachable |
| RPC calls | Backend function errors |
| Any `404`/`500` | Missing resource |

---

## Quick Reference: Common White Screen Causes

| Symptom | Likely Cause | Fix |
|---|---|---|
| Prints 1-4 but NOT 5 | Crash in ProviderContainer creation or sync engine | Wrap in try-catch |
| Shows spinner forever | Context Engine `isLoading` never becomes `false` | Check `ContextController.init()` — remote fetch failing |
| Router Bypassed works, real router doesn't | GoRouter redirect loop or bad initialLocation | Check `redirect` logic and `initialLocation` |
| Dashboard: error shown | moduleProvider failing | Check ModuleRegistry and Supabase data |
| Blank with no errors | `return null` or empty widget tree | Search for missing return statements |
