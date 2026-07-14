/// ============================================================
/// CAPABILITY PROFILE — ORGANIZATION'S OPERATIONAL PROFILE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/domain/ = capability domain models
///
/// A CapabilityProfile represents the set of capabilities and
/// their levels that a specific organization has been granted.
///
/// This is NOT a subscription tier. It is NOT a user role.
/// It is an operational profile that determines what the
/// organization can actually do in the system.
///
/// ✅ Responsibilities:
///   - Hold a set of (capabilityId, level) pairs for an organization
///   - Pure data — no evaluation logic
///   - Designed for future backend persistence
///
/// ❌ Does NOT:
///   - Evaluate access
///   - Check against registry
///   - Import providers or UI
/// ============================================================
library;

import 'package:famhub_app/core/capabilities/domain/capability.dart';

/// ============================================================
/// CAPABILITY PROFILE
/// ============================================================
///
/// Immutable snapshot of what capabilities an organization has.
/// Maps capability IDs to their assigned level integers.
/// ============================================================
class CapabilityProfile {
  /// Organization identifier this profile belongs to
  final String organizationId;

  /// Map of capabilityId → assigned level
  final Map<String, int> capabilities;

  const CapabilityProfile({
    required this.organizationId,
    this.capabilities = const {},
  });

  /// ============================================================
  /// QUERY HELPERS
  /// ============================================================

  /// Get the assigned level for a capability.
  /// Returns 0 (disabled) if not found.
  int levelFor(String capabilityId) =>
      capabilities[capabilityId] ?? 0;

  /// Check if a capability is enabled (level > 0).
  bool hasCapability(String capabilityId) =>
      (capabilities[capabilityId] ?? 0) > 0;

  /// Check if a capability meets or exceeds a minimum level.
  bool hasCapabilityAtLevel(String capabilityId, int minimumLevel) =>
      (capabilities[capabilityId] ?? 0) >= minimumLevel;

  /// Check if multiple capabilities are all enabled.
  bool hasAllCapabilities(List<String> capabilityIds) =>
      capabilityIds.every(hasCapability);

  /// Check if any of the given capabilities is enabled.
  bool hasAnyCapability(List<String> capabilityIds) =>
      capabilityIds.any(hasCapability);

  /// Get all enabled capability IDs (level > 0).
  List<String> get enabledCapabilityIds =>
      capabilities.entries
          .where((e) => e.value > 0)
          .map((e) => e.key)
          .toList();

  /// Get all domain groups that have at least one enabled capability.
  List<String> get enabledDomains {
    final domains = <String>{};
    for (final entry in capabilities.entries) {
      if (entry.value > 0) {
        final domain = Capabilities.byId(entry.key)?.domain ?? 'unknown';
        domains.add(domain);
      }
    }
    return domains.toList();
  }

  /// Number of enabled capabilities.
  int get enabledCount =>
      capabilities.values.where((l) => l > 0).length;

  /// Total number of capabilities in this profile.
  int get totalCount => capabilities.length;

  /// Create a copy with updated capabilities.
  CapabilityProfile copyWith({
    String? organizationId,
    Map<String, int>? capabilities,
  }) {
    return CapabilityProfile(
      organizationId: organizationId ?? this.organizationId,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  /// Merge another profile into this one.
  /// The other profile's values take precedence.
  CapabilityProfile merge(CapabilityProfile other) {
    final merged = Map<String, int>.from(capabilities);
    merged.addAll(other.capabilities);
    return CapabilityProfile(
      organizationId: organizationId,
      capabilities: merged,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapabilityProfile &&
          runtimeType == other.runtimeType &&
          organizationId == other.organizationId;

  @override
  int get hashCode => organizationId.hashCode;

  @override
  String toString() =>
      'CapabilityProfile($organizationId: $enabledCount/$totalCount enabled)';
}

/// ============================================================
/// CAPABILITY PROFILE FACTORY
/// ============================================================
///
/// Creates default and preset CapabilityProfiles.
/// In production, profiles come from the backend.
/// ============================================================
abstract final class CapabilityProfileFactory {
  CapabilityProfileFactory._();

  /// Create an empty profile (all capabilities disabled).
  static CapabilityProfile empty(String organizationId) =>
      CapabilityProfile(organizationId: organizationId);

  /// Create a full profile (all capabilities at max level).
  static CapabilityProfile full(String organizationId) {
    final all = <String, int>{};
    // In production, read from CapabilityRegistry
    // For now, use predefined list
    const capabilityIds = [
      'marketplace.listings',
      'marketplace.orders',
      'inventory.stock',
      'inventory.warehouse',
      'workflow.execution',
      'finance.recording',
      'finance.invoicing',
      'analytics.basic',
      'analytics.advanced',
      'traceability.basic',
      'traceability.export',
      'logistics.dispatch',
      'logistics.tracking',
      'staff.management',
      'coldchain.monitoring',
      'ai.recommendations',
    ];
    for (final id in capabilityIds) {
      all[id] = 999; // Arbitrarily high level = max available
    }
    return CapabilityProfile(
      organizationId: organizationId,
      capabilities: all,
    );
  }

  /// Create a basic farmer profile.
  static CapabilityProfile basicFarmer(String organizationId) =>
      CapabilityProfile(
        organizationId: organizationId,
        capabilities: {
          'marketplace.listings': 1,
          'marketplace.orders': 1,
          'inventory.stock': 1,
          'workflow.execution': 1,
          'finance.recording': 1,
          'analytics.basic': 1,
          'traceability.basic': 1,
          'logistics.tracking': 1,
          'staff.management': 1,
        },
      );

  /// Create an aggregator profile with additional capabilities.
  static CapabilityProfile aggregator(String organizationId) =>
      CapabilityProfile(
        organizationId: organizationId,
        capabilities: {
          'marketplace.listings': 1,
          'marketplace.orders': 1,
          'inventory.stock': 1,
          'inventory.warehouse': 1,
          'workflow.execution': 3,
          'finance.recording': 1,
          'finance.invoicing': 1,
          'analytics.basic': 1,
          'analytics.advanced': 1,
          'traceability.basic': 1,
          'traceability.export': 1,
          'logistics.dispatch': 1,
          'logistics.tracking': 1,
          'staff.management': 1,
        },
      );

  /// Create an enterprise profile with all capabilities.
  static CapabilityProfile enterprise(String organizationId) =>
      CapabilityProfile(
        organizationId: organizationId,
        capabilities: {
          'marketplace.listings': 1,
          'marketplace.orders': 1,
          'inventory.stock': 1,
          'inventory.warehouse': 1,
          'workflow.execution': 6,
          'finance.recording': 1,
          'finance.invoicing': 1,
          'analytics.basic': 1,
          'analytics.advanced': 3,
          'traceability.basic': 1,
          'traceability.export': 1,
          'logistics.dispatch': 1,
          'logistics.tracking': 1,
          'staff.management': 2,
          'coldchain.monitoring': 1,
          'ai.recommendations': 1,
        },
      );

  /// Create a profile from a map (future backend alignment).
  static CapabilityProfile fromMap({
    required String organizationId,
    required Map<String, dynamic> map,
  }) {
    final capabilities = <String, int>{};
    for (final entry in map.entries) {
      if (entry.value is int) {
        capabilities[entry.key] = entry.value as int;
      } else if (entry.value is num) {
        capabilities[entry.key] = (entry.value as num).toInt();
      }
    }
    return CapabilityProfile(
      organizationId: organizationId,
      capabilities: capabilities,
    );
  }
}
