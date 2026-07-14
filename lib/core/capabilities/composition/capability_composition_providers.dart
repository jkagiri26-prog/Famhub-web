/// ============================================================
/// CAPABILITY-AWARE COMPOSITION PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/composition/ = composition integration
///
/// These providers extend the existing composition providers
/// with capability-based filtering.
///
/// Target Pipeline:
///   Organization → Capability Profile → Capability Engine →
///   RuntimeDescriptorEngine → Navigation → Dashboard
///
/// ✅ Responsibilities:
///   - Filter dashboard widgets by capability requirements
///   - Filter navigation items by capability requirements
///   - Provide capability-aware composition queries
///
/// ❌ Does NOT:
///   - Replace existing composition providers
///   - Perform UI rendering
///   - Duplicate RuntimeFeatureFlags logic
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/capabilities/application/capability_engine.dart';
import 'package:famhub_app/core/capabilities/application/capability_provider.dart';
import 'package:famhub_app/core/capabilities/composition/capability_composition_bridge.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/composition/providers/composition_providers.dart';
import 'package:famhub_app/core/composition/navigation/composition_nav_builder.dart';

/// ============================================================
/// PROVIDER: CAPABILITY BRIDGE
/// ============================================================
///
/// Provides a CapabilityCompositionBridge instance backed by
/// the current CapabilityEngine.
/// ============================================================
final capabilityCompositionBridgeProvider =
    Provider<CapabilityCompositionBridge?>((ref) {
  final engine = ref.watch(capabilityEngineProvider);
  if (engine == null) return null;
  return CapabilityCompositionBridge(engine: engine);
});

/// ============================================================
/// PROVIDER: CAPABILITY-FILTERED DASHBOARD WIDGETS
/// ============================================================
///
/// Extends dashboardWidgetDescriptorsProvider with capability
/// filtering. Only widgets whose required capabilities are
/// available will appear.
///
/// Usage:
///   final widgets = ref.watch(capabilityFilteredDashboardWidgetsProvider);
/// ============================================================
final capabilityFilteredDashboardWidgetsProvider =
    FutureProvider<List<DashboardWidgetDescriptor>>((ref) async {
  final widgets = await ref.watch(dashboardWidgetDescriptorsProvider.future);
  final bridge = ref.watch(capabilityCompositionBridgeProvider);
  if (bridge == null) return widgets;
  return bridge.filterDashboardWidgets(widgets);
});

/// ============================================================
/// PROVIDER: CAPABILITY-FILTERED DASHBOARD WIDGETS BY SECTION
/// ============================================================
///
/// Dashboard widgets grouped by section, filtered by capabilities.
/// ============================================================
final capabilityFilteredDashboardWidgetsBySectionProvider =
    FutureProvider<Map<String, List<DashboardWidgetDescriptor>>>((ref) async {
  final filteredWidgets = await ref.watch(
    capabilityFilteredDashboardWidgetsProvider.future,
  );

  final sectionMap = <String, List<DashboardWidgetDescriptor>>{};
  for (final widget in filteredWidgets) {
    sectionMap.putIfAbsent(widget.sectionKey, () => []);
    sectionMap[widget.sectionKey]!.add(widget);
  }
  return sectionMap;
});

/// ============================================================
/// PROVIDER: CAPABILITY-FILTERED SIDEBAR ITEMS
/// ============================================================
///
/// Sidebar navigation items filtered by module capability viability.
/// ============================================================
final capabilityFilteredSidebarItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final items = ref.watch(compositionSidebarItemsProvider);
  final bridge = ref.watch(capabilityCompositionBridgeProvider);
  if (bridge == null) return items;
  return bridge.filterNavItems(items, (item) => item.moduleKey);
});

/// ============================================================
/// PROVIDER: CAPABILITY-FILTERED BOTTOM NAV ITEMS
/// ============================================================
///
/// Bottom navigation items filtered by module capability viability.
/// ============================================================
final capabilityFilteredBottomNavItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final items = ref.watch(compositionBottomNavItemsProvider);
  final bridge = ref.watch(capabilityCompositionBridgeProvider);
  if (bridge == null) return items;
  return bridge.filterNavItems(items, (item) => item.moduleKey);
});

/// ============================================================
/// PROVIDER: CAPABILITY-FILTERED DASHBOARD NAV ITEMS
/// ============================================================
///
/// Dashboard navigation items filtered by module capability viability.
/// ============================================================
final capabilityFilteredDashboardNavItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final items = ref.watch(compositionDashboardNavItemsProvider);
  final bridge = ref.watch(capabilityCompositionBridgeProvider);
  if (bridge == null) return items;
  return bridge.filterNavItems(items, (item) => item.moduleKey);
});

/// ============================================================
/// PROVIDER: CAPABILITY-FILTERED QUICK ACTION ITEMS
/// ============================================================
///
/// Quick action items filtered by module capability viability.
/// ============================================================
final capabilityFilteredQuickActionItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final items = ref.watch(compositionQuickActionItemsProvider);
  final bridge = ref.watch(capabilityCompositionBridgeProvider);
  if (bridge == null) return items;
  return bridge.filterNavItems(items, (item) => item.moduleKey);
});

/// ============================================================
/// PROVIDER: CAPABILITY-FILTERED HOME WIDGETS
/// ============================================================
///
/// Home widgets filtered by module capability viability.
/// ============================================================
final capabilityFilteredHomeWidgetsProvider =
    FutureProvider<List<HomeWidgetDescriptor>>((ref) async {
  final widgets = await ref.watch(homeWidgetDescriptorsProvider.future);
  final bridge = ref.watch(capabilityCompositionBridgeProvider);
  if (bridge == null) return widgets;

  // Filter home widgets by their module's viability
  return widgets.where((widget) {
    // Home widgets don't have a moduleKey on the descriptor.
    // For now, we just return all home widgets.
    // TODO: Add module key to HomeWidgetDescriptor if needed.
    return true;
  }).toList();
});
