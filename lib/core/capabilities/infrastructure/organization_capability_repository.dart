/// ============================================================
/// ORGANIZATION CAPABILITY REPOSITORY — FUTURE BACKEND ALIGNMENT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/infrastructure/ = infrastructure layer
///
/// This repository defines the contract for fetching organization
/// capability profiles from a data source.
///
/// ✅ CURRENT STATE (Stage 3):
///   - Stub implementation returning default profiles
///   - Can be replaced with real backend calls
///
/// ✅ FUTURE STATE:
///   - Will call backend API (GET /organizations/{id}/capabilities)
///   - Will query organization_capabilities table
///   - Will support realtime updates
///
/// ✅ POTENTIAL FUTURE TABLES:
///   organizations
///   organization_capabilities
///   capabilities
///   capability_levels
///
/// ❌ Does NOT:
///   - Evaluate capabilities
///   - Import UI
///   - Contain business logic
/// ============================================================
library;

import 'package:famhub_app/core/capabilities/domain/capability_profile.dart';
import 'package:famhub_app/core/capabilities/registry/capability_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ============================================================
/// ORGANIZATION CAPABILITY REPOSITORY
/// ============================================================
///
/// Abstract contract for fetching capability profiles.
/// Enables clean future backend integration without
/// changing the domain or application layers.
/// ============================================================
abstract class OrganizationCapabilityRepository {
  /// Get the capability profile for an organization.
  Future<CapabilityProfile?> getProfile(String organizationId);

  /// Update a capability level for an organization.
  Future<void> setCapabilityLevel(
    String organizationId,
    String capabilityId,
    int level,
  );

  /// Set multiple capability levels at once.
  Future<void> setCapabilityLevels(
    String organizationId,
    Map<String, int> capabilities,
  );

  /// Listen for realtime profile changes.
  Stream<CapabilityProfile> watchProfile(String organizationId);
}

/// ============================================================
/// IN-MEMORY CAPABILITY REPOSITORY (STAGE 3 STUB)
/// ============================================================
///
/// In-memory implementation for Stage 3 development.
/// All profiles are derived from presets.
///
/// 🔄 Replace with real backend implementation when
///    the backend capability system is available.
/// ============================================================
class InMemoryCapabilityRepository
    implements OrganizationCapabilityRepository {
  /// Storage map for custom profiles
  final Map<String, CapabilityProfile> _profiles = {};

  @override
  Future<CapabilityProfile?> getProfile(String organizationId) async {
    // Check stored custom profiles first
    if (_profiles.containsKey(organizationId)) {
      return _profiles[organizationId];
    }

    // Fall back to a full profile for dev/demo
    return CapabilityProfileFactory.full(organizationId);
  }

  @override
  Future<void> setCapabilityLevel(
    String organizationId,
    String capabilityId,
    int level,
  ) async {
    final existing = _profiles[organizationId] ??
        CapabilityProfileFactory.empty(organizationId);

    final updated = Map<String, int>.from(existing.capabilities);
    updated[capabilityId] = level;

    _profiles[organizationId] = CapabilityProfile(
      organizationId: organizationId,
      capabilities: updated,
    );
  }

  @override
  Future<void> setCapabilityLevels(
    String organizationId,
    Map<String, int> capabilities,
  ) async {
    final existing = _profiles[organizationId] ??
        CapabilityProfileFactory.empty(organizationId);

    final merged = Map<String, int>.from(existing.capabilities);
    merged.addAll(capabilities);

    _profiles[organizationId] = CapabilityProfile(
      organizationId: organizationId,
      capabilities: merged,
    );
  }

  @override
  Stream<CapabilityProfile> watchProfile(String organizationId) async* {
    // Initial emission
    final profile = await getProfile(organizationId);
    if (profile != null) yield profile;

    // In a real implementation, this would listen to
    // Realtime changes from the backend.
  }

  /// Reset all stored profiles (for testing).
  void reset() {
    _profiles.clear();
  }
}

/// ============================================================
/// REPOSITORY PROVIDER
/// ============================================================
///
/// Riverpod provider for the capability repository.
/// Swap this to the real backend implementation when ready.
/// ============================================================
final organizationCapabilityRepositoryProvider =
    Provider<OrganizationCapabilityRepository>((ref) {
  // TODO: Replace with real backend implementation.
  return InMemoryCapabilityRepository();
});
