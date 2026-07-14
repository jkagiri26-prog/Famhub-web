/// ============================================================
/// POLICY-AWARE COMPOSITION PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/composition/ = composition integration
///
/// These providers extend the existing composition providers
/// with policy-based filtering.
///
/// Runtime Pipeline Order:
///   Entity Context
///     ↓
///   Capability Profile
///     ↓
///   Effective Policy ← (we are here)
///     ↓
///   Access Decision
///     ↓
///   Runtime Feature Flags
///     ↓
///   Composition
///     ↓
///   Shell
///     ↓
///   Widgets
///
/// ✅ Responsibilities:
///   - Filter dashboard widgets by policy rules
///   - Filter navigation items by policy rules
///   - Filter quick actions by policy rules
///   - Provide policy-aware composition queries
///
/// ❌ Does NOT:
///   - Replace existing composition providers
///   - Replace CapabilityCompositionBridge providers
///   - Perform UI rendering
///   - Evaluate feature flags
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/policies/domain/policy.dart';
import 'package:famhub_app/core/policies/application/policy_engine.dart';
import 'package:famhub_app/core/policies/application/policy_provider.dart';
import 'package:famhub_app/core/policies/composition/policy_composition_bridge.dart';
import 'package:famhub_app/core/composition/navigation/composition_nav_builder.dart';
import 'package:famhub_app/core/composition/providers/composition_providers.dart';

/// ============================================================
/// PROVIDER: POLICY COMPOSITION BRIDGE
/// ============================================================
///
/// Provides a PolicyCompositionBridge instance backed by
/// the current PolicyEngine.
/// ============================================================
final policyCompositionBridgeProvider =
    Provider<PolicyCompositionBridge?>((ref) {
  final engine = ref.watch(policyEngineProvider);
  if (engine == null) return null;
  return PolicyCompositionBridge(engine: engine);
});

/// ============================================================
/// PROVIDER: POLICY-FILTERED SIDEBAR ITEMS
/// ============================================================
///
/// Sidebar navigation items filtered by policy rules.
/// ============================================================
final policyFilteredSidebarItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final items = ref.watch(compositionSidebarItemsProvider);
  final bridge = ref.watch(policyCompositionBridgeProvider);
  if (bridge == null) return items;
  // Filter sidebar items by checking if their module is allowed
  return items.where((item) {
    return bridge.isModuleAllowed(item.moduleKey);
  }).toList();
});

/// ============================================================
/// PROVIDER: POLICY-FILTERED BOTTOM NAV ITEMS
/// ============================================================
///
/// Bottom navigation items filtered by policy rules.
/// ============================================================
final policyFilteredBottomNavItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final items = ref.watch(compositionBottomNavItemsProvider);
  final bridge = ref.watch(policyCompositionBridgeProvider);
  if (bridge == null) return items;
  return items.where((item) {
    return bridge.isModuleAllowed(item.moduleKey);
  }).toList();
});

/// ============================================================
/// PROVIDER: POLICY-FILTERED DASHBOARD NAV ITEMS
/// ============================================================
///
/// Dashboard navigation items filtered by policy rules.
/// ============================================================
final policyFilteredDashboardNavItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final items = ref.watch(compositionDashboardNavItemsProvider);
  final bridge = ref.watch(policyCompositionBridgeProvider);
  if (bridge == null) return items;
  return items.where((item) {
    return bridge.isModuleAllowed(item.moduleKey);
  }).toList();
});

/// ============================================================
/// PROVIDER: POLICY-FILTERED QUICK ACTION ITEMS
/// ============================================================
///
/// Quick action items filtered by policy rules.
/// ============================================================
final policyFilteredQuickActionItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final items = ref.watch(compositionQuickActionItemsProvider);
  final bridge = ref.watch(policyCompositionBridgeProvider);
  if (bridge == null) return items;
  return items.where((item) {
    return bridge.isModuleAllowed(item.moduleKey);
  }).toList();
});

/// ============================================================
/// PROVIDER: WORKFLOW EXECUTION ALLOWED
/// ============================================================
///
/// Checks if workflow execution is allowed by policy.
/// All workflow pages must check this.
/// ============================================================
final isWorkflowAllowedByPolicyProvider = Provider<bool>((ref) {
  final bridge = ref.watch(policyCompositionBridgeProvider);
  if (bridge == null) return true; // Default to allowed if no bridge
  return bridge.isWorkflowAllowed;
});

/// ============================================================
/// PROVIDER: MAX IMAGE UPLOAD LIMIT
/// ============================================================
///
/// Provides the maximum image upload limit from policy.
/// Never hardcode 3, 5, 10 images — always use this.
/// ============================================================
final maxImageUploadLimitProvider = Provider<int>((ref) {
  final bridge = ref.watch(policyCompositionBridgeProvider);
  if (bridge == null) return 6; // Sensible default
  return bridge.maxImageUploadLimit;
});


