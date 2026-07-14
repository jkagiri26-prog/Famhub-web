/// ============================================================
/// CAPABILITY REGISTRY — PURE DECLARATIONS CATALOG
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/registry/ = capability registry layer
///
/// The registry is a pure declaration catalog. It contains
/// NO business logic, NO evaluation, NO UI imports.
///
/// Every capability and its levels are registered here.
/// This is the single source of truth for what capabilities
/// exist in the system.
///
/// ✅ Responsibilities:
///   - Register all known capabilities
///   - Define level schemes for each capability
///   - Pure lookups and queries
///   - Support future backend alignment (capabilities table)
///
/// ❌ Does NOT:
///   - Evaluate access
///   - Contain business logic
///   - Import providers or UI
///   - Evaluate subscription/organization type
/// ============================================================
library;

import 'package:famhub_app/core/capabilities/domain/capability.dart';
import 'package:famhub_app/core/capabilities/domain/capability_level.dart';

/// ============================================================
/// CAPABILITY REGISTRATION ENTRY
/// ============================================================
///
/// Binds a capability to its level scheme and default level.
/// ============================================================
class CapabilityRegistration {
  /// The capability being registered
  final Capability capability;

  /// Available levels for this capability
  final List<CapabilityLevel> levels;

  /// Default level when no profile is set
  final int defaultLevel;

  const CapabilityRegistration({
    required this.capability,
    required this.levels,
    this.defaultLevel = 0,
  });

  CapabilityLevel get defaultCapabilityLevel =>
      levels.firstWhere(
        (l) => l.level == defaultLevel,
        orElse: () => levels.first,
      );

  CapabilityLevel? levelFor(int level) {
    for (final l in levels) {
      if (l.level == level) return l;
    }
    return null;
  }

  bool hasLevel(int level) =>
      levels.any((l) => l.level == level);
}

/// ============================================================
/// CAPABILITY REGISTRY
/// ============================================================
///
/// Static registry where all capabilities are declared.
/// This is the permanent catalog — capabilities are contracts
/// and should not be removed once registered.
/// ============================================================
class CapabilityRegistry {
  static final Map<String, CapabilityRegistration> _registry = {};

  /// ============================================================
  /// REGISTER A CAPABILITY
  /// ============================================================
  ///
  /// Registers a capability with its level scheme.
  /// Must be called during app initialization.
  /// ============================================================
  static void register(CapabilityRegistration registration) {
    _registry[registration.capability.id] = registration;
  }

  /// ============================================================
  /// REGISTER ALL DEFAULT CAPABILITIES
  /// ============================================================
  ///
  /// Convenience method to register all system capabilities
  /// with their default level schemes.
  ///
  /// Called once during app bootstrap.
  /// ============================================================
  static void registerDefaults() {
    // ── Marketplace ──
    register(const CapabilityRegistration(
      capability: Capabilities.marketplaceListings,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 1,
    ));
    register(const CapabilityRegistration(
      capability: Capabilities.marketplaceOrders,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 1,
    ));

    // ── Inventory ──
    register(const CapabilityRegistration(
      capability: Capabilities.inventoryStock,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 1,
    ));
    register(const CapabilityRegistration(
      capability: Capabilities.inventoryWarehouse,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 1,
    ));

    // ── Workflow ──
    register(const CapabilityRegistration(
      capability: Capabilities.workflowExecution,
      levels: CapabilityLevelPresets.workflowLevels,
      defaultLevel: 1,
    ));

    // ── Finance ──
    register(const CapabilityRegistration(
      capability: Capabilities.financeRecording,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 1,
    ));
    register(const CapabilityRegistration(
      capability: Capabilities.financeInvoicing,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 1,
    ));

    // ── Analytics ──
    register(const CapabilityRegistration(
      capability: Capabilities.analyticsBasic,
      levels: CapabilityLevelPresets.analyticsLevels,
      defaultLevel: 1,
    ));
    register(const CapabilityRegistration(
      capability: Capabilities.analyticsAdvanced,
      levels: CapabilityLevelPresets.threeTierLevels,
      defaultLevel: 0,
    ));

    // ── Traceability ──
    register(const CapabilityRegistration(
      capability: Capabilities.traceabilityBasic,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 1,
    ));
    register(const CapabilityRegistration(
      capability: Capabilities.traceabilityExport,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 0,
    ));

    // ── Logistics ──
    register(const CapabilityRegistration(
      capability: Capabilities.logisticsDispatch,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 1,
    ));
    register(const CapabilityRegistration(
      capability: Capabilities.logisticsTracking,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 1,
    ));

    // ── Staff ──
    register(const CapabilityRegistration(
      capability: Capabilities.staffManagement,
      levels: CapabilityLevelPresets.threeTierLevels,
      defaultLevel: 1,
    ));

    // ── Cold Chain ──
    register(const CapabilityRegistration(
      capability: Capabilities.coldchainMonitoring,
      levels: CapabilityLevelPresets.binaryLevels,
      defaultLevel: 0,
    ));

    // ── AI ──
    register(const CapabilityRegistration(
      capability: Capabilities.aiRecommendations,
      levels: CapabilityLevelPresets.threeTierLevels,
      defaultLevel: 0,
    ));
  }

  // ============================================================
  // QUERY METHODS
  // ============================================================

  /// Get a capability registration by its id.
  static CapabilityRegistration? get(String capabilityId) {
    return _registry[capabilityId];
  }

  /// Check if a capability is registered.
  static bool hasCapability(String capabilityId) {
    return _registry.containsKey(capabilityId);
  }

  /// Get all registered capability IDs.
  static List<String> get registeredCapabilityIds =>
      _registry.keys.toList();

  /// Get all registered capabilities.
  static List<Capability> get allCapabilities =>
      _registry.values.map((r) => r.capability).toList();

  /// Get all registrations.
  static List<CapabilityRegistration> get allRegistrations =>
      _registry.values.toList();

  /// Get all capabilities for a given domain.
  static List<CapabilityRegistration> forDomain(String domain) {
    return _registry.values
        .where((r) => r.capability.domain == domain)
        .toList();
  }

  /// Get the available levels for a capability.
  static List<CapabilityLevel>? levelsFor(String capabilityId) {
    return _registry[capabilityId]?.levels;
  }

  /// Get the default level for a capability.
  static int defaultLevelFor(String capabilityId) {
    return _registry[capabilityId]?.defaultLevel ?? 0;
  }

  /// Check if a capability has a specific level available.
  static bool hasLevel(String capabilityId, int level) {
    return _registry[capabilityId]?.hasLevel(level) ?? false;
  }

  /// Clear all registrations (testing / hot reload).
  static void clear() {
    _registry.clear();
  }
}
