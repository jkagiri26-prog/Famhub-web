/// ============================================================
/// ORGANIZATION RUNTIME REPOSITORY — DATA ACCESS CONTRACT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/organization_runtime/infrastructure/ = infrastructure layer
///
/// This repository defines the contract for loading and storing
/// the active organization context.
///
/// ✅ CURRENT STATE (Stage 3):
///   - In-memory stub implementation
///   - Returns default organization context
///
/// ✅ FUTURE STATE:
///   - Will call backend API
///   - Will load from organizations table
///   - Will support organization membership queries
///
/// ✅ DESIGN PRINCIPLE:
///   The frontend should only consume the runtime,
///   never backend tables directly.
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/organization_runtime/domain/organization_context.dart';
import 'package:famhub_app/core/organization_runtime/domain/organization_type.dart';

/// ============================================================
/// ORGANIZATION RUNTIME REPOSITORY
/// ============================================================
///
/// Abstract contract for organization data access.
/// Enables clean future backend integration without
/// changing the domain or application layers.
/// ============================================================
abstract class OrganizationRuntimeRepository {
  /// Load the active organization context.
  ///
  /// Returns the organization context for the currently
  /// active organization (from storage/backend).
  Future<OrganizationContext> loadActiveOrganization();

  /// Get organization context by ID.
  Future<OrganizationContext> getOrganizationContext(
    String organizationId,
  );

  /// Set the active organization.
  ///
  /// Persists the organization switch to local storage
  /// (and eventually backend).
  Future<void> setActiveOrganization(String organizationId);

  /// Get all organizations the current user belongs to.
  Future<List<OrganizationSummary>> getUserOrganizations();
}

/// ============================================================
/// ORGANIZATION SUMMARY
/// ============================================================
///
/// Lightweight organization info for lists/switching.
/// ============================================================
class OrganizationSummary {
  final String organizationId;
  final String organizationName;
  final OrganizationType organizationType;

  const OrganizationSummary({
    required this.organizationId,
    required this.organizationName,
    this.organizationType = OrganizationType.unknown,
  });
}

/// ============================================================
/// IN-MEMORY ORGANIZATION RUNTIME REPOSITORY (STAGE 3 STUB)
/// ============================================================
///
/// In-memory implementation for Stage 3 development.
/// Returns a default organization context.
///
/// 🔄 Replace with real backend implementation when
///    the backend organization system is available.
/// ============================================================
class InMemoryOrganizationRuntimeRepository
    implements OrganizationRuntimeRepository {
  /// Currently active organization ID
  String _activeOrganizationId = 'org-default-001';

  /// Stored organization contexts
  final Map<String, OrganizationContext> _organizations = {
    'org-default-001': const OrganizationContext(
      organizationId: 'org-default-001',
      organizationName: 'Default Farm',
      organizationType: OrganizationType.farmer,
      countryId: 'KE',
      regionId: 'Rift_Valley',
      countyId: 'Nakuru',
      subCountyId: 'Njoro',
      wardId: 'Ward_1',
      capabilityProfileId: 'profile-farmer-001',
      policyProfileId: 'policy-default-001',
      subscriptionId: 'sub-basic-001',
      status: OrganizationStatus.active,
      isVerified: true,
    ),
    'org-aggregator-001': const OrganizationContext(
      organizationId: 'org-aggregator-001',
      organizationName: 'Central Aggregators Ltd',
      organizationType: OrganizationType.aggregator,
      countryId: 'KE',
      regionId: 'Rift_Valley',
      countyId: 'Nakuru',
      subCountyId: 'Njoro',
      wardId: 'Ward_2',
      capabilityProfileId: 'profile-aggregator-001',
      policyProfileId: 'policy-aggregator-001',
      subscriptionId: 'sub-premium-001',
      status: OrganizationStatus.active,
      isVerified: true,
    ),
    'org-enterprise-001': const OrganizationContext(
      organizationId: 'org-enterprise-001',
      organizationName: 'Kenya Exports Inc',
      organizationType: OrganizationType.enterprise,
      countryId: 'KE',
      regionId: 'Coast',
      countyId: 'Mombasa',
      subCountyId: 'Changamwe',
      wardId: 'Port',
      capabilityProfileId: 'profile-enterprise-001',
      policyProfileId: 'policy-enterprise-001',
      subscriptionId: 'sub-enterprise-001',
      status: OrganizationStatus.active,
      isVerified: true,
    ),
    'org-govt-001': const OrganizationContext(
      organizationId: 'org-govt-001',
      organizationName: 'Nakuru County Agriculture',
      organizationType: OrganizationType.countyOffice,
      countryId: 'KE',
      regionId: 'Rift_Valley',
      countyId: 'Nakuru',
      capabilityProfileId: 'profile-government-001',
      policyProfileId: 'policy-govt-001',
      subscriptionId: 'sub-enterprise-001',
      status: OrganizationStatus.active,
      isVerified: true,
    ),
    'org-coop-001': const OrganizationContext(
      organizationId: 'org-coop-001',
      organizationName: 'Njoro Farmers Cooperative',
      organizationType: OrganizationType.cooperative,
      countryId: 'KE',
      regionId: 'Rift_Valley',
      countyId: 'Nakuru',
      subCountyId: 'Njoro',
      subscriptionId: 'sub-basic-001',
      status: OrganizationStatus.active,
      isVerified: false,
    ),
  };

  @override
  Future<OrganizationContext> loadActiveOrganization() async {
    return _organizations[_activeOrganizationId] ??
        OrganizationContext(
          organizationId: _activeOrganizationId,
          organizationName: 'Unknown Organization',
          status: OrganizationStatus.unknown,
        );
  }

  @override
  Future<OrganizationContext> getOrganizationContext(
    String organizationId,
  ) async {
    return _organizations[organizationId] ??
        OrganizationContext(
          organizationId: organizationId,
          organizationName: 'Unknown Organization',
          status: OrganizationStatus.unknown,
        );
  }

  @override
  Future<void> setActiveOrganization(String organizationId) async {
    _activeOrganizationId = organizationId;
  }

  @override
  Future<List<OrganizationSummary>> getUserOrganizations() async {
    return _organizations.entries.map((entry) {
      return OrganizationSummary(
        organizationId: entry.key,
        organizationName: entry.value.organizationName,
        organizationType: entry.value.organizationType,
      );
    }).toList();
  }

  /// Add a custom organization context (for testing).
  void addOrganization(OrganizationContext context) {
    _organizations[context.organizationId] = context;
  }
}

/// ============================================================
/// REPOSITORY PROVIDER
/// ============================================================
///
/// Riverpod provider for the organization runtime repository.
/// Swap this to the real backend implementation when ready.
/// ============================================================
final organizationRuntimeRepositoryProvider =
    Provider<OrganizationRuntimeRepository>((ref) {
  // TODO: Replace with real backend implementation.
  return InMemoryOrganizationRuntimeRepository();
});