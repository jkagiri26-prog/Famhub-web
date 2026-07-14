/// ============================================================
/// ORGANIZATION RUNTIME ENGINE — CORE ORCHESTRATOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/organization_runtime/application/ = application layer
///
/// The Organization Runtime Engine is the central orchestrator
/// for the active organization. It manages loading, switching,
/// refreshing, and querying the organization state.
///
/// ✅ Responsibilities:
///   - load()              — Load the active organization from storage/backend
///   - switchOrganization()— Switch to a different organization
///   - refresh()           — Refresh all runtime dependencies
///   - current()           — Get the current organization context
///   - isVerified()        — Check verification status
///   - isEnterprise()      — Check enterprise type
///   - isGovernment()      — Check government type
///   - isActive()          — Check active status
///
/// ❌ Does NOT:
///   - Contain UI
///   - Contain Flutter
///   - Replace the backend organizations table
///   - Hold state directly (state lives in OrganizationContext)
///
/// ✅ Architecture:
///   - All organization logic lives here, NOT in Entity Context
///   - NOT in Capability Engine
///   - This is the SINGLE source of truth for the active organization
///
/// ✅ Refresh Pipeline:
///   When organization changes, this engine triggers a complete
///   refresh of:
///   - Entity Context
///   - Capability Profile
///   - Effective Policy
///   - Access Decisions
///   - Runtime Feature Flags
///   - Runtime Decision Engine
///   - Navigation
///   - Dashboard
///   - Quick Actions
///   - Widgets
/// ============================================================
library;

import 'package:famhub_app/core/organization_runtime/domain/organization_context.dart';
import 'package:famhub_app/core/organization_runtime/domain/organization_type.dart';
import 'package:famhub_app/core/organization_runtime/infrastructure/organization_runtime_repository.dart';

/// ============================================================
/// ORGANIZATION RUNTIME ENGINE
/// ============================================================
///
/// Pure logic engine for organization runtime operations.
/// All I/O is delegated to the repository.
/// ============================================================
class OrganizationRuntimeEngine {
  final OrganizationRuntimeRepository _repository;

  OrganizationRuntimeEngine({required OrganizationRuntimeRepository repository})
      : _repository = repository;

  // ============================================================
  // PUBLIC API
  // ============================================================

  /// ============================================================
  /// LOAD
  /// ============================================================
  ///
  /// Load the active organization from the repository.
  /// Returns the current OrganizationContext.
  ///
  /// This is the INITIALIZATION method. Call once on app startup
  /// or when the user logs in.
  /// ============================================================
  Future<OrganizationContext> load() async {
    final context = await _repository.loadActiveOrganization();
    return context;
  }

  /// ============================================================
  /// SWITCH ORGANIZATION
  /// ============================================================
  ///
  /// Switch the active organization to a different one.
  ///
  /// Supports future scenarios like:
  ///   James → Farm A → Farm B → Aggregator → Export Company → County Office
  ///
  /// The switch triggers a complete runtime refresh:
  ///   - Entity Context
  ///   - Capability Profile
  ///   - Effective Policy
  ///   - Access Decisions
  ///   - Runtime Feature Flags
  ///   - Runtime Decision Engine
  ///   - Navigation, Dashboard, Quick Actions, Widgets
  ///
  /// Returns the new active organization context.
  /// ============================================================
  Future<OrganizationContext> switchOrganization(String organizationId) async {
    // Persist the switch
    await _repository.setActiveOrganization(organizationId);

    // Load the new context
    final newContext = await _repository.getOrganizationContext(organizationId);

    // NOTE: The actual invalidation of Riverpod providers is handled
    // by the ActiveOrganizationNotifier in active_organization_provider.dart.
    // This engine only handles the business logic and I/O.
    return newContext;
  }

  /// ============================================================
  /// REFRESH
  /// ============================================================
  ///
  /// Re-fetch the current organization context from the repository.
  /// Useful after settings changes or sync operations.
  /// ============================================================
  Future<OrganizationContext> refresh() async {
    final context = await _repository.loadActiveOrganization();
    return context;
  }

  /// ============================================================
  /// CURRENT
  /// ============================================================
  ///
  /// Returns the current organization context.
  /// This is a synchronous read. The context must already be loaded.
  /// ============================================================
  OrganizationContext current(OrganizationContext currentContext) {
    return currentContext;
  }

  /// ============================================================
  /// IS VERIFIED
  /// ============================================================
  ///
  /// Check if the current organization is verified.
  /// ============================================================
  bool isVerified(OrganizationContext context) {
    return context.isVerified;
  }

  /// ============================================================
  /// IS ENTERPRISE
  /// ============================================================
  ///
  /// Check if the current organization is an enterprise type.
  /// ============================================================
  bool isEnterprise(OrganizationContext context) {
    return context.isEnterprise;
  }

  /// ============================================================
  /// IS GOVERNMENT
  /// ============================================================
  ///
  /// Check if the current organization is a government type.
  /// ============================================================
  bool isGovernment(OrganizationContext context) {
    return context.isGovernment;
  }

  /// ============================================================
  /// IS ACTIVE
  /// ============================================================
  ///
  /// Check if the current organization is active.
  /// ============================================================
  bool isActive(OrganizationContext context) {
    return context.isActive;
  }

  /// ============================================================
  /// GET TYPE-SPECIFIC FLAGS
  /// ============================================================
  ///
  /// Quick checks for common organization types.
  /// ============================================================

  bool isFarmer(OrganizationContext context) =>
      context.organizationType == OrganizationType.farmer;

  bool isCooperative(OrganizationContext context) =>
      context.organizationType == OrganizationType.cooperative;

  bool isAggregator(OrganizationContext context) =>
      context.organizationType == OrganizationType.aggregator;

  bool isExporter(OrganizationContext context) =>
      context.organizationType == OrganizationType.exporter;

  bool isProcessor(OrganizationContext context) =>
      context.organizationType == OrganizationType.processor;

  bool isCountyOffice(OrganizationContext context) =>
      context.organizationType == OrganizationType.countyOffice;

  bool isNgo(OrganizationContext context) =>
      context.organizationType == OrganizationType.ngo;

  /// ============================================================
  /// HAS GEOGRAPHIC HIERARCHY
  /// ============================================================
  ///
  /// Check if the organization has a full geographic hierarchy
  /// (country → region → county → subCounty → ward).
  /// ============================================================
  bool hasFullGeography(OrganizationContext context) {
    return context.countryId != null &&
        context.countryId!.isNotEmpty &&
        context.countyId != null &&
        context.countyId!.isNotEmpty;
  }

  /// ============================================================
  /// HAS SUBSCRIPTION
  /// ============================================================
  ///
  /// Check if the organization has an active subscription.
  /// ============================================================
  bool hasSubscription(OrganizationContext context) {
    return context.subscriptionId != null &&
        context.subscriptionId!.isNotEmpty;
  }
}
