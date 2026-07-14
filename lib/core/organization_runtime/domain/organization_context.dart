/// ============================================================
/// ORGANIZATION CONTEXT — RUNTIME STATE MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/organization_runtime/domain/ = organization domain models
///
/// This is RUNTIME STATE. Not a database model.
///
/// OrganizationContext is the single source of truth for the
/// active organization's metadata. Every feature should read
/// from this context instead of querying organizationId,
/// organizationType, countryId, countyId, etc. from different
/// places.
///
/// ✅ Responsibilities:
///   - Hold the active organization's complete runtime state
///   - Expose computed flags: isVerified, isGovernment, isEnterprise, isActive
///   - Be immutable — create new instances on state change
///
/// ❌ Does NOT:
///   - Contain database logic
///   - Contain UI logic
///   - Replace the backend organizations table
///
/// ✅ Future Backend Alignment:
///   The backend will be the source of:
///   - organization membership
///   - active organization
///   - organization hierarchy
///   - organization verification
///   - subscriptions
///   - capability profile
///   - policy profile
///
///   The frontend will only consume the runtime, never backend tables directly.
/// ============================================================
library;

import 'package:famhub_app/core/organization_runtime/domain/organization_type.dart';

/// ============================================================
/// ORGANIZATION CONTEXT
/// ============================================================
///
/// Immutable snapshot of the active organization state.
/// Create a new instance whenever any field changes.
/// ============================================================
class OrganizationContext {
  /// Unique identifier for the organization
  final String organizationId;

  /// Display name of the organization
  final String organizationName;

  /// Organization type classification
  final OrganizationType organizationType;

  /// Geographic identifiers
  final String? countryId;
  final String? regionId;
  final String? countyId;
  final String? subCountyId;
  final String? wardId;

  /// Profile references
  final String? capabilityProfileId;
  final String? policyProfileId;

  /// Subscription identifier
  final String? subscriptionId;

  /// Organization status
  final OrganizationStatus status;

  /// Verification status
  final bool isVerified;

  // ── Computed flags ──

  /// Whether this org is a government entity
  bool get isGovernment =>
      organizationType == OrganizationType.government ||
      organizationType == OrganizationType.countyOffice;

  /// Whether this org is enterprise/commercial
  bool get isEnterprise =>
      organizationType == OrganizationType.enterprise ||
      organizationType == OrganizationType.exporter ||
      organizationType == OrganizationType.processor;

  /// Whether the organization is active
  bool get isActive => status == OrganizationStatus.active;

  /// Whether the organization is fully onboarded
  bool get isOnboarded => status != OrganizationStatus.pending;

  /// Whether context has meaningful data
  bool get isEmpty =>
      organizationId.isEmpty || status == OrganizationStatus.unknown;

  const OrganizationContext({
    this.organizationId = '',
    this.organizationName = '',
    this.organizationType = OrganizationType.unknown,
    this.countryId,
    this.regionId,
    this.countyId,
    this.subCountyId,
    this.wardId,
    this.capabilityProfileId,
    this.policyProfileId,
    this.subscriptionId,
    this.status = OrganizationStatus.unknown,
    this.isVerified = false,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  ///
  /// Create a new OrganizationContext with updated fields.
  /// ============================================================
  OrganizationContext copyWith({
    String? organizationId,
    String? organizationName,
    OrganizationType? organizationType,
    String? countryId,
    String? regionId,
    String? countyId,
    String? subCountyId,
    String? wardId,
    String? capabilityProfileId,
    String? policyProfileId,
    String? subscriptionId,
    OrganizationStatus? status,
    bool? isVerified,
  }) {
    return OrganizationContext(
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      organizationType: organizationType ?? this.organizationType,
      countryId: countryId ?? this.countryId,
      regionId: regionId ?? this.regionId,
      countyId: countyId ?? this.countyId,
      subCountyId: subCountyId ?? this.subCountyId,
      wardId: wardId ?? this.wardId,
      capabilityProfileId: capabilityProfileId ?? this.capabilityProfileId,
      policyProfileId: policyProfileId ?? this.policyProfileId,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  /// Empty (unset) context
  static const empty = OrganizationContext();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizationContext &&
          organizationId == other.organizationId &&
          organizationName == other.organizationName &&
          organizationType == other.organizationType &&
          countryId == other.countryId &&
          regionId == other.regionId &&
          countyId == other.countyId &&
          subCountyId == other.subCountyId &&
          wardId == other.wardId &&
          capabilityProfileId == other.capabilityProfileId &&
          policyProfileId == other.policyProfileId &&
          subscriptionId == other.subscriptionId &&
          status == other.status &&
          isVerified == other.isVerified;

  @override
  int get hashCode => Object.hash(
        organizationId,
        organizationName,
        organizationType,
        countryId,
        regionId,
        countyId,
        subCountyId,
        wardId,
        capabilityProfileId,
        policyProfileId,
        subscriptionId,
        status,
        isVerified,
      );

  @override
  String toString() =>
      'OrganizationContext($organizationName [$organizationType] — $organizationId)';
}

/// ============================================================
/// ORGANIZATION STATUS
/// ============================================================
///
/// Represents the lifecycle state of an organization.
/// ============================================================
enum OrganizationStatus {
  /// Unknown / unset
  unknown,

  /// Initial registration, not yet fully set up
  pending,

  /// Active and operational
  active,

  /// Temporarily suspended
  suspended,

  /// Permanently deactivated
  deactivated,

  /// Under review
  underReview,
}
