/// ============================================================
/// ORGANIZATION SDK — Public facade for organization runtime
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// ✅ Responsibilities:
///   - Expose organization state to feature modules
///   - Delegate to activeOrganizationProvider
///   - Never expose OrganizationRuntimeEngine directly
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain persistence logic
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/organization_runtime/domain/organization_context.dart';
import 'package:famhub_app/core/organization_runtime/domain/organization_type.dart';
import 'package:famhub_app/core/organization_runtime/application/active_organization_provider.dart';
import 'api/sdk_annotations.dart';

/// ============================================================
/// ORGANIZATION SDK
/// ============================================================
///
/// Feature modules use this instead of reading providers directly.
///
/// Usage:
///   final org = ref.read(famhubOrganizationSdkProvider);
///   final id = org.organizationId();
///   final name = org.organizationName();
///   final isEnterprise = org.isEnterprise();
///   await org.switchOrganization('org-123');
/// ============================================================
@PublicSdk()
class OrganizationSdk {
  final Ref _ref;

  OrganizationSdk(this._ref);

  /// The current organization context
  OrganizationContext get _ctx =>
      _ref.read(activeOrganizationProvider);

  /// The current organization context (reactive)
  @SdkMethod(version: '1.0.0')
  OrganizationContext watch() =>
      _ref.watch(activeOrganizationProvider);

  /// Get the current organization's ID
  @SdkMethod(version: '1.0.0')
  String organizationId() => _ctx.organizationId;

  /// Get the current organization's display name
  @SdkMethod(version: '1.0.0')
  String organizationName() => _ctx.organizationName;

  /// Get the current organization's type
  @SdkMethod(version: '1.0.0')
  OrganizationType organizationType() => _ctx.organizationType;

  /// Switch to a different organization
  @SdkMethod(version: '1.0.0')
  Future<void> switchOrganization(String organizationId) async {
    await _ref.read(activeOrganizationProvider.notifier).switchOrganization(organizationId);
  }

  /// Refresh the current organization from backend
  @SdkMethod(version: '1.0.0')
  Future<void> refreshOrganization() async {
    await _ref.read(activeOrganizationProvider.notifier).refresh();
  }

  /// Check if the organization is verified
  @SdkMethod(version: '1.0.0')
  bool isVerified() => _ctx.isVerified;

  /// Check if the organization is a government entity
  @SdkMethod(version: '1.0.0')
  bool isGovernment() => _ctx.isGovernment;

  /// Check if the organization is an enterprise
  @SdkMethod(version: '1.0.0')
  bool isEnterprise() => _ctx.isEnterprise;

  /// Check if the organization is active
  @SdkMethod(version: '1.0.0')
  bool isActive() => _ctx.isActive;

  /// Check if the organization is fully onboarded
  @SdkMethod(version: '1.0.0')
  bool isOnboarded() => _ctx.isOnboarded;

  /// Get the organization's country ID
  @SdkMethod(version: '1.0.0')
  String? countryId() => _ctx.countryId;

  /// Get the organization's county ID
  @SdkMethod(version: '1.0.0')
  String? countyId() => _ctx.countyId;

  /// Get the organization's subscription ID
  @SdkMethod(version: '1.0.0')
  String? subscriptionId() => _ctx.subscriptionId;

  /// Check if the organization is a specific type
  @SdkMethod(version: '1.0.0')
  bool isType(OrganizationType type) => _ctx.organizationType == type;

  /// Check if the organization is a farmer
  @SdkMethod(version: '1.0.0')
  bool isFarmer() => _ctx.organizationType == OrganizationType.farmer;

  /// Check if the organization is a cooperative
  @SdkMethod(version: '1.0.0')
  bool isCooperative() => _ctx.organizationType == OrganizationType.cooperative;

  /// Check if the organization is an aggregator
  @SdkMethod(version: '1.0.0')
  bool isAggregator() => _ctx.organizationType == OrganizationType.aggregator;

  /// Check if the organization is an exporter
  @SdkMethod(version: '1.0.0')
  bool isExporter() => _ctx.organizationType == OrganizationType.exporter;
}

/// ============================================================
/// PROVIDER: ORGANIZATION SDK
/// ============================================================
@SdkProvider()
final famhubOrganizationSdkProvider = Provider<OrganizationSdk>((ref) {
  return OrganizationSdk(ref);
});
