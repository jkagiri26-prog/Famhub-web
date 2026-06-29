/// ============================================================
/// NAVIGATION CONFIG PROVIDERS (ENTERPRISE GOVERNANCE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Provide backend-driven navigation items
///   - Filter by sidebar/bottom/dashboard/launcher/quick action visibility
///   - Apply context engine access control
///   - Apply RuntimeFeatureFlags governance evaluation
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Every UI decision comes from backend configuration
///   - Context Engine + RuntimeFeatureFlags for ALL governance rules
///   - No hardcoded module lists, routes, or names
///
/// ❌ Does NOT:
///   - Render widget trees
///   - Contain presentation logic
///   - Hardcode module routes or names
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/navigation/nav_item.dart';
import 'package:famhub_app/core/navigation/unified_nav_builder.dart';
import 'package:famhub_app/core/feature_flags/application/services/runtime_feature_flags.dart';

/// ============================================================
/// PROVIDER: SIDEBAR NAVIGATION ITEMS
/// ============================================================
///
/// Generates backend-driven sidebar items.
/// Filters by sidebar_visible + Context Engine + RuntimeFeatureFlags.
/// ============================================================
final sidebarNavItemsProvider = Provider<List<NavItem>>((ref) {
  final modulesAsync = ref.watch(moduleProvider);
  final context = ref.watch(contextProvider);

  return modulesAsync.when(
    data: (modules) => _buildNavItems(modules, context,
        forSidebar: true),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// ============================================================
/// PROVIDER: BOTTOM NAVIGATION ITEMS
/// ============================================================
///
/// Generates backend-driven bottom navigation items.
/// Filters by bottom_nav_visible + Context Engine + RuntimeFeatureFlags.
/// ============================================================
final bottomNavItemsProvider = Provider<List<NavItem>>((ref) {
  final modulesAsync = ref.watch(moduleProvider);
  final context = ref.watch(contextProvider);

  return modulesAsync.when(
    data: (modules) => _buildNavItems(modules, context,
        forSidebar: false),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// ============================================================
/// PROVIDER: DASHBOARD MODULE ITEMS
/// ============================================================
///
/// Generates backend-driven dashboard tiles.
/// Filters by dashboard_visible + Context Engine + RuntimeFeatureFlags.
/// ============================================================
final dashboardNavItemsProvider = Provider<List<NavItem>>((ref) {
  final modulesAsync = ref.watch(moduleProvider);
  final context = ref.watch(contextProvider);

  return modulesAsync.when(
    data: (modules) => _buildNavItems(modules, context,
        forDashboard: true),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// ============================================================
/// PROVIDER: QUICK ACTION ITEMS
/// ============================================================
///
/// Items for launcher/quick action UI.
/// Filters by quick_action_visible.
/// ============================================================
final quickActionItemsProvider = Provider<List<NavItem>>((ref) {
  final modulesAsync = ref.watch(moduleProvider);
  final context = ref.watch(contextProvider);

  return modulesAsync.when(
    data: (modules) => _buildNavItems(modules, context,
        forQuickAction: true),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// ============================================================
/// PROVIDER: PINNED MODULE ITEMS
/// ============================================================
///
/// Only modules with `pinned = true` and accessible.
/// ============================================================
final pinnedNavItemsProvider = Provider<List<NavItem>>((ref) {
  final modulesAsync = ref.watch(moduleProvider);
  final context = ref.watch(contextProvider);

  return modulesAsync.when(
    data: (modules) => _buildNavItems(modules, context,
        onlyPinned: true),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// ============================================================
/// INTERNAL: Build nav items from modules with governance
/// ============================================================
///
/// Every module passes through:
/// 1. Visibility flags (sidebar/bottom/dashboard/quick action)
/// 2. Context Engine (guest, role, tier)
/// 3. RuntimeFeatureFlags (maintenance, subscription, device)
/// 4. UnifiedNavBuilder (icon/route resolution)
/// ============================================================
List<NavItem> _buildNavItems(
  List<SystemModule> modules,
  EntityContext context, {
  bool forSidebar = false,
  bool forDashboard = false,
  bool forQuickAction = false,
  bool onlyPinned = false,
}) {
  final items = <NavItem>[];

  for (final module in modules) {
    // ── 1. Visibility filter ──
    if (forSidebar && !module.sidebarVisible) continue;
    if (!forSidebar && !forDashboard && !forQuickAction && !module.bottomNavVisible) continue;
    if (forDashboard && !module.dashboardVisible) continue;
    if (forQuickAction && !module.quickActionVisible) continue;

    // ── 2. Pinned filter ──
    if (onlyPinned && !module.pinned) continue;

    // ── 3. Context Engine + RuntimeFeatureFlags governance ──
    final featureResult = RuntimeFeatureFlags.evaluateModule(
      module: module,
      context: context,
    );
    if (!featureResult.isAllowed) continue;

    // ── 4. Convert to NavItem with all governance fields ──
    final navItem = UnifiedNavBuilder.buildNavItem(module);
    items.add(navItem);
  }

  // Sort by display order (pinned items first within same order)
  items.sort((a, b) {
    if (a.pinned && !b.pinned) return -1;
    if (!a.pinned && b.pinned) return 1;
    return a.displayOrder.compareTo(b.displayOrder);
  });

  return items;
}


