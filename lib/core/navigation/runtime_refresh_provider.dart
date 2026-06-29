import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/navigation/nav_config.dart';

/// ============================================================
/// RUNTIME REFRESH PROVIDER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Auto-invalidate navigation providers when context changes
///   - Auto-invalidate navigation providers when modules change
///   - No app restart required for reflected changes
///   - Scoped invalidation (only affected providers)
///
/// ✅ TRIGGERS:
///   - modules enabled/disabled
///   - permissions change
///   - subscriptions change
///   - context changes
///   - feature flags change
///
/// ❌ Does NOT:
///   - Render UI
///   - Contain business logic
///   - Control execution flow
/// ============================================================

/// ============================================================
/// RUNTIME REFRESH OBSERVER
/// ============================================================
///
/// Watches for changes in modules and context,
/// then invalidates relevant navigation providers.
///
/// Connect this in your app shell to enable auto-refresh.
/// ============================================================
final runtimeRefreshObserverProvider = Provider<void Function()>((ref) {
  // Watch both modules and context reactively
  ref.watch(moduleProvider);
  ref.watch(contextProvider);

  // When either changes, provide a callback to manually invalidate
  return () {
    ref.invalidate(sidebarNavItemsProvider);
    ref.invalidate(bottomNavItemsProvider);
    ref.invalidate(dashboardNavItemsProvider);
    ref.invalidate(quickActionItemsProvider);
    ref.invalidate(pinnedNavItemsProvider);
  };
});

/// ============================================================
/// AUTO-INVALIDATION WATCHER
/// ============================================================
///
/// Automatically invalidates navigation providers
/// when modules or context change.
///
/// Usage: In your app shell widget, call:
///   ref.listen(runtimeAutoInvalidatorProvider, (_, __) {});
/// ============================================================
final runtimeAutoInvalidatorProvider = Provider<void>((ref) {
  // Watch module provider to auto-invalidate nav providers when modules change
  final modules = ref.watch(moduleProvider);
  // Watch context to auto-rebuild when user context changes
  ref.watch(contextProvider);

  // When data resolves, invalidate navigation providers
  modules.when(
    data: (_) {
      ref.invalidate(sidebarNavItemsProvider);
      ref.invalidate(bottomNavItemsProvider);
      ref.invalidate(dashboardNavItemsProvider);
      ref.invalidate(quickActionItemsProvider);
      ref.invalidate(pinnedNavItemsProvider);
    },
    loading: () {},
    error: (_, __) {},
  );

  // Also invalidate on context changes via listener
  ref.listen(contextProvider, (previous, next) {
    if (previous != next) {
      ref.invalidate(sidebarNavItemsProvider);
      ref.invalidate(bottomNavItemsProvider);
      ref.invalidate(dashboardNavItemsProvider);
      ref.invalidate(quickActionItemsProvider);
      ref.invalidate(pinnedNavItemsProvider);
    }
  });

  return;
});
