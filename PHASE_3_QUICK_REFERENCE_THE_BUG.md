# PHASE 3 QUICK REFERENCE: THE BUG & THE FIX

---

## THE BUG (One Sentence)

main.dart calls `.init()` on a class that doesn't have that method.

---

## WHERE

**File**: [lib/main.dart](lib/main.%20dart/main.dart)  
**Lines**: 5-6 (import) + 70 (call)

---

## THE CODE (Current - BROKEN)

```dart
// Line 5-6: WRONG IMPORT
import 'core/context/context_provider.dart';

// Line 70: CRASHES HERE
Future.microtask(() async {
  await ref.read(contextProvider.notifier).init();  ← NoSuchMethodError
});
```

---

## WHY IT CRASHES

```
core/context/context_notifier.dart (Line 5+)
  class ContextNotifier extends StateNotifier<AppContext> {
    void setUser(String userId, {String? entityId}) { ... }
    void setRole(UserRole role) { ... }
    void setLoading(bool loading) { ... }
    void reset() { ... }
    // No init() method exists!
  }
```

---

## THE CORRECT CODE (Fix)

### Option 1: Import the right module

```dart
// Lines 5-6: CORRECT IMPORT
import 'core/context_engine/providers/context_provider.dart';

// Line 70: NOW WORKS
Future.microtask(() async {
  await ref.read(contextProvider.notifier).init();  ← Works! (ContextController HAS init())
});
```

**Evidence**: [lib/core/context_engine/controllers/context_controller.dart](lib/core/context_engine/controllers/context_controller.dart#L14)
```dart
Future<void> init() async {
  state = state.copyWith(isLoading: true);
  final local = await storage.load();
  state = state.copyWith(...);
  try {
    final remote = await sync.fetchUserContext();
    state = EntityContext(...);
    await storage.save(...);
  } catch (e) {
    state = state.copyWith(isLoading: false);
  }
}
```

### Option 2: Add init() to ContextNotifier

```dart
// core/context/context_notifier.dart
class ContextNotifier extends StateNotifier<AppContext> {
  // ... existing methods ...
  
  Future<void> init() async {
    setLoading(true);
    // TODO: Implement persistence logic
    setLoading(false);
  }
}
```

---

## WHICH OPTION?

**Phase 2 audit found**: context_engine has full persistence logic

**Recommendation**: **Option 1** - Use context_engine, which has working init()

---

## ADDITIONAL FIXES NEEDED

After fixing the import, also add error handling:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(...);
  } catch (e) {
    print('Supabase init failed: $e');
    // Exit or show error screen
    return;
  }

  try {
    await DashboardBootstrap.initializeFromSystem();
  } catch (e) {
    print('Dashboard bootstrap failed: $e');
    return;
  }

  try {
    await runtimeSyncEngine.initialize();
  } catch (e) {
    print('Runtime sync init failed: $e');
    return;
  }

  runApp(...);
}
```

---

## VERIFICATION

After fixing, run the app:
1. App should start without loading spinner
2. User should see main screen
3. Check local storage: user data should be there

Current behavior:
1. Loading spinner shows
2. App crashes with: `NoSuchMethodError: 'init' is not a member of 'ContextNotifier'`
3. App is non-functional

---

## IMPACT

| Aspect | Current | After Fix |
|--------|---------|-----------|
| App Starts | 🔴 Crashes | ✅ Works |
| User Persists | 🔴 Never loads | ✅ Loads from storage |
| Error Handling | 🔴 None | ✅ Graceful |
| Context Init | 🔴 Broken | ✅ Functional |

---

## Timeline

- **To Fix**: 10-15 minutes (change import + add try-catch)
- **To Test**: 5 minutes (run app, verify login)
- **To Deploy**: Standard process

---

## This is NOT a design flaw.

This is a simple **bug**: wrong import + missing error handling.

The design is actually good (mostly). The implementation has one line wrong.

**Status**: Fixable immediately. 🟢 LOW EFFORT
