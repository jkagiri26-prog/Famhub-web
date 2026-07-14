/// ============================================================
/// POLICY REPOSITORY — DATA ACCESS CONTRACT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/infrastructure/ = infrastructure layer
///
/// This repository defines the contract for fetching effective
/// policies from a data source.
///
/// The repository simply fetches policy data. No evaluation.
/// No filtering. Backend owns policy resolution.
///
/// ✅ Responsibilities:
///   - Define the contract for policy data access
///   - Fetch EffectivePolicy for an org/location
///
/// ❌ Does NOT:
///   - Evaluate policies
///   - Apply defaults
///   - Filter or transform
///   - Import UI
/// ============================================================
library;

import 'package:famhub_app/core/policies/domain/effective_policy.dart';

/// ============================================================
/// POLICY REPOSITORY
/// ============================================================
///
/// Abstract contract for fetching effective policies.
/// Enables clean future backend integration without
/// changing the domain or application layers.
/// ============================================================
abstract class PolicyRepository {
  /// Get the effective policy for an organization and location.
  ///
  /// The backend owns policy resolution. This method simply
  /// fetches the fully resolved policy document.
  Future<EffectivePolicy> getEffectivePolicy({
    required String organizationId,
    required String locationId,
  });

  /// Listen for realtime policy changes.
  Stream<EffectivePolicy> watchEffectivePolicy({
    required String organizationId,
    required String locationId,
  });
}

/// ============================================================
/// IN-MEMORY POLICY REPOSITORY (STAGE 3 STUB)
/// ============================================================
///
/// In-memory implementation for Stage 3 development.
/// Returns default policies with all rules enabled.
///
/// 🔄 Replace with SupabasePolicyRepository when the
///    backend policy system is available.
/// ============================================================
class InMemoryPolicyRepository implements PolicyRepository {
  const InMemoryPolicyRepository();

  @override
  Future<EffectivePolicy> getEffectivePolicy({
    required String organizationId,
    required String locationId,
  }) async {
    // Default policy — all rules enabled with safe defaults
    return EffectivePolicy(
      rules: {
        'workflow.execution': true,
        'inventory.tracking': true,
        'marketplace.selling': true,
        'marketplace.buying': true,
        'marketplace.orders': true,
        'upload.max_images': 6,
        'traceability.enabled': true,
        'finance.recording': true,
        'analytics.enabled': true,
        'ai.assistant': false,
        'staff.management': true,
        'export.certification': false,
        'coldchain.enabled': false,
        'logistics.enabled': true,
        'contract.farming': false,
        'region.restriction': <String>[],
      },
      locationId: locationId,
      organizationId: organizationId,
      version: '1.0',
    );
  }

  @override
  Stream<EffectivePolicy> watchEffectivePolicy({
    required String organizationId,
    required String locationId,
  }) async* {
    // Initial emission
    yield await getEffectivePolicy(
      organizationId: organizationId,
      locationId: locationId,
    );

    // In a real implementation, this would listen to
    // Realtime changes from the backend.
  }
}
