/// ============================================================
/// ORGANIZATION RUNTIME BRIDGE — COMPOSITION INTEGRATION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/organization_runtime/composition/ = composition integration
///
/// The Organization Runtime Bridge feeds the:
///   - Capability Engine
///   - Policy Engine
///   - Access Engine
///   - Runtime Decision Engine
///
/// from ONE source: the Organization Context.
///
/// No engine should load organizations independently.
/// All organization data flows through this bridge.
///
/// ✅ Responsibilities:
///   - Provide the active organization to all engines
///   - Ensure no engine loads organizations independently
///   - Provide convenience methods for engine consumers
///
/// ✅ Usage:
///   ```dart
///   final bridge = ref.watch(organizationRuntimeBridgeProvider);
///   final engine = bridge.capabilityEngine();
///   final org = bridge.activeOrganization;
///   ```
///
/// ❌ Does NOT:
///   - Contain UI
///   - Replace individual engines
///   - Evaluate decisions
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/organization_runtime/domain/organization_context.dart';
import 'package:famhub_app/core/organization_runtime/domain/organization_type.dart';
import 'package:famhub_app/core/organization_runtime/application/active_organization_provider.dart';
import 'package:famhub_app/core/organization_runtime/application/organization_runtime_engine.dart';
import 'package:famhub_app/core/organization_runtime/application/organization_runtime_provider.dart';

/// ============================================================
/// ORGANIZATION RUNTIME BRIDGE
/// ============================================================
///
/// Provides a single access point for the active organization
/// to all downstream engines.
///
/// Integrates with:
///   - OrganizationRuntimeEngine (business logic)
///   - OrganizationContext (state)
///   - ActiveOrganizationProvider (Riverpod integration)
/// ============================================================
class OrganizationRuntimeBridge {
  final OrganizationContext _context;
  final OrganizationRuntimeEngine _engine;

  const OrganizationRuntimeBridge({
    required OrganizationContext context,
    required OrganizationRuntimeEngine engine,
  })  : _context = context,
        _engine = engine;

  // ============================================================
  // ORGANIZATION CONTEXT ACCESS
  // ============================================================

  /// The active organization context
  OrganizationContext get activeOrganization => _context;

  /// The active organization ID
  String get organizationId => _context.organizationId;

  /// The active organization name
  String get organizationName => _context.organizationName;

  /// The active organization type
  OrganizationType get organizationType => _context.organizationType;

  /// Geographic identifiers
  String? get countryId => _context.countryId;
  String? get regionId => _context.regionId;
  String? get countyId => _context.countyId;
  String? get subCountyId => _context.subCountyId;
  String? get wardId => _context.wardId;

  /// Profile references
  String? get capabilityProfileId => _context.capabilityProfileId;
  String? get policyProfileId => _context.policyProfileId;

  /// Subscription
  String? get subscriptionId => _context.subscriptionId;

  /// Status and verification
  OrganizationStatus get status => _context.status;
  bool get isVerified => _context.isVerified;
  bool get isActive => _context.isActive;
  bool get isEmpty => _context.isEmpty;

  // ============================================================
  // COMPUTED FLAGS (delegated to engine)
  // ============================================================

  bool get isEnterprise => _engine.isEnterprise(_context);
  bool get isGovernment => _engine.isGovernment(_context);
  bool get isFarmer => _engine.isFarmer(_context);
  bool get isCooperative => _engine.isCooperative(_context);
  bool get isAggregator => _engine.isAggregator(_context);
  bool get isExporter => _engine.isExporter(_context);
  bool get isCountyOffice => _engine.isCountyOffice(_context);

  /// Check if org has full geographic hierarchy
  bool get hasFullGeography => _engine.hasFullGeography(_context);

  /// Check if org has a subscription
  bool get hasSubscription => _engine.hasSubscription(_context);

  // ============================================================
  // ENGINE METHODS (for consumers that need the engine directly)
  // ============================================================

  /// Get the runtime engine (for switch/refresh operations)
  OrganizationRuntimeEngine get engine => _engine;

  /// Get raw context (for passing to decision engines)
  OrganizationContext get context => _context;
}

/// ============================================================
/// PROVIDER: ORGANIZATION RUNTIME BRIDGE
/// ============================================================
///
/// Provides the OrganizationRuntimeBridge for all engines to consume.
///
/// Every engine (Capability, Policy, Access, Runtime Decision)
/// should use this bridge to read the active organization instead
/// of reading organizationId, organizationType, etc. independently.
///
/// ✅ Usage:
///   ```dart
///   final bridge = ref.watch(organizationRuntimeBridgeProvider);
///
///   // Read org info
///   final orgId = bridge.organizationId;
///   final country = bridge.countryId;
///
///   // Check computed flags
///   if (bridge.isEnterprise) { ... }
///   if (bridge.isGovernment) { ... }
///
///   // Access engine for operations
///   await bridge.engine.switchOrganization('new-org-id');
///   ```
/// ============================================================
final organizationRuntimeBridgeProvider =
    Provider<OrganizationRuntimeBridge>((ref) {
  final context = ref.watch(activeOrganizationProvider);
  final engine = ref.watch(organizationRuntimeEngineProvider);
  return OrganizationRuntimeBridge(context: context, engine: engine);
});
