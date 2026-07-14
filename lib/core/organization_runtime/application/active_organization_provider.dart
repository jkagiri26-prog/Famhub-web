/// ============================================================
/// ACTIVE ORGANIZATION PROVIDER — SINGLE SOURCE OF TRUTH
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/organization_runtime/application/ = application layer
///
/// EVERY feature should read `activeOrganizationProvider` instead of
/// reading organizationId, organizationType, country, county
/// from multiple places.
///
/// ✅ Responsibilities:
///   - Single source of truth for the active organization
///   - Auto-invalidate on organization switch
///   - Provide computed flags: isVerified, isEnterprise, isGovernment, isActive
///   - Manage the runtime refresh pipeline
///
/// ✅ Usage:
///   ```dart
///   final org = ref.watch(activeOrganizationProvider);
///   if (org.isEmpty) { /* show loading / empty state */ }
///   if (org.isEnterprise) { /* show enterprise features */ }
///   if (org.isGovernment) { /* show government features */ }
///   ```
///
/// ✅ Pipeline Integration:
///   When the active organization changes, this provider triggers
///   invalidation of:
///   - Entity Context (contextProvider)
///   - Capability Profile (capabilityProfileProvider)
///   - Effective Policy (effectivePolicyProvider)
///   - Access Decisions (accessPolicyProvider)
///   - Runtime Feature Flags (runtimeFlagsProvider)
///   - Runtime Decision Engine (runtimeDecisionEngineProvider)
///   - Navigation (sidebarNavItemsProvider, etc.)
///   - Dashboard (dashboardWidgetDescriptorsProvider, etc.)
///   - Quick Actions (compositionQuickActionItemsProvider)
///
/// ❌ Does NOT:
///   - Contain UI
///   - Contain database logic
///   - Replace backend tables
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/organization_runtime/domain/organization_context.dart';
import 'package:famhub_app/core/organization_runtime/application/organization_runtime_engine.dart';
import 'package:famhub_app/core/organization_runtime/application/organization_runtime_provider.dart';

// ── Refresh Pipeline Imports ──
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/capabilities/application/capability_profile_provider.dart';
import 'package:famhub_app/core/capabilities/application/capability_provider.dart';
import 'package:famhub_app/core/policies/application/effective_policy_provider.dart';
import 'package:famhub_app/core/policies/application/policy_provider.dart';
import 'package:famhub_app/core/access/application/providers/access_policy_provider.dart';
import 'package:famhub_app/core/feature_flags/application/providers/runtime_flags_provider.dart';
import 'package:famhub_app/core/runtime_decision/application/runtime_decision_provider.dart';
import 'package:famhub_app/core/navigation/nav_config.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/core/capabilities/composition/capability_composition_providers.dart';

/// ============================================================
/// ACTIVE ORGANIZATION NOTIFIER
/// ============================================================
///
/// Manages the active organization state and triggers
/// the runtime refresh pipeline on changes.
/// ============================================================
class ActiveOrganizationNotifier extends Notifier<OrganizationContext> {
  @override
  OrganizationContext build() {
    // Start with empty context
    return OrganizationContext.empty;
  }

  /// ============================================================
  /// INIT
  /// ============================================================
  ///
  /// Load the active organization from the engine.
  /// Called on app startup and login.
  /// ============================================================
  Future<void> init() async {
    final engine = ref.read(organizationRuntimeEngineProvider);
    final context = await engine.load();
    state = context;
    _triggerRuntimeRefresh();
  }

  /// ============================================================
  /// SWITCH ORGANIZATION
  /// ============================================================
  ///
  /// Switch to a different organization.
  /// Automatically refreshes the entire runtime.
  /// ============================================================
  Future<void> switchOrganization(String organizationId) async {
    final engine = ref.read(organizationRuntimeEngineProvider);
    final newContext = await engine.switchOrganization(organizationId);
    state = newContext;
    _triggerRuntimeRefresh();
  }

  /// ============================================================
  /// REFRESH
  /// ============================================================
  ///
  /// Re-fetch the current organization and trigger refresh pipeline.
  /// ============================================================
  Future<void> refresh() async {
    final engine = ref.read(organizationRuntimeEngineProvider);
    final context = await engine.refresh();
    state = context;
    _triggerRuntimeRefresh();
  }

  /// ============================================================
  /// UPDATE CONTEXT
  /// ============================================================
  ///
  /// Directly update the organization context without a full reload.
  /// Useful for optimistic updates.
  /// ============================================================
  void updateContext(OrganizationContext updated) {
    state = updated;
    // No refresh pipeline trigger — caller should call refresh() if needed.
  }

  /// ============================================================
  /// CLEAR
  /// ============================================================
  ///
  /// Reset to empty state on logout.
  /// ============================================================
  void clear() {
    state = OrganizationContext.empty;
  }

  /// ============================================================
  /// TRIGGER RUNTIME REFRESH
  /// ============================================================
  ///
  /// Invalidates all downstream providers that depend on
  /// the active organization.
  ///
  /// When organization changes, automatically refresh:
  /// - Entity Context
  /// - Capability Profile
  /// - Effective Policy
  /// - Access Decisions
  /// - Runtime Feature Flags
  /// - Runtime Decision Engine
  /// - Navigation
  /// - Dashboard
  /// - Quick Actions
  /// - Widgets
  /// ============================================================
  void _triggerRuntimeRefresh() {
    // ── Entity Context ──
    ref.invalidate(contextProvider);

    // ── Capability Profile ──
    ref.invalidate(capabilityProfileProvider);
    ref.invalidate(capabilityEngineProvider);

    // ── Effective Policy ──
    ref.invalidate(effectivePolicyProvider);
    ref.invalidate(policyEngineProvider);

    // ── Access Decisions ──
    ref.invalidate(accessPolicyProvider);

    // ── Runtime Feature Flags ──
    ref.invalidate(runtimeFlagsProvider);

    // ── Runtime Decision Engine ──
    ref.invalidate(runtimeDecisionEngineProvider);

    // ── Navigation ──
    ref.invalidate(sidebarNavItemsProvider);
    ref.invalidate(bottomNavItemsProvider);
    ref.invalidate(dashboardNavItemsProvider);
    ref.invalidate(quickActionItemsProvider);
    ref.invalidate(pinnedNavItemsProvider);

    // ── Dashboard ──
    ref.invalidate(dashboardWidgetDescriptorsProvider);
    ref.invalidate(capabilityFilteredDashboardWidgetsProvider);
    ref.invalidate(capabilityFilteredDashboardWidgetsBySectionProvider);

    // ── Home widgets ──
    ref.invalidate(capabilityFilteredHomeWidgetsProvider);
  }
}

/// ============================================================
/// PROVIDER: ACTIVE ORGANIZATION
/// ============================================================
///
/// EVERY feature uses this provider to read the active organization.
///
/// ✅ Usage:
///   ```dart
///   final org = ref.watch(activeOrganizationProvider);
///
///   // Access fields directly
///   final id = org.organizationId;
///   final type = org.organizationType;
///   final country = org.countryId;
///
///   // Use computed flags
///   if (org.isEnterprise) { ... }
///   if (org.isVerified) { ... }
///   if (org.isGovernment) { ... }
///   ```
/// ============================================================
final activeOrganizationProvider =
    NotifierProvider<ActiveOrganizationNotifier, OrganizationContext>(
  ActiveOrganizationNotifier.new,
);
