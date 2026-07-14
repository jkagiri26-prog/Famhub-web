/// ============================================================
/// EFFECTIVE POLICY PROVIDER — POLICY DATA SOURCE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/application/ = policy application layer
///
/// This provider is the single source of truth for the current
/// effective policy for the active organization and location.
///
/// Fetches from the repository and caches the result.
/// Re-fetches when organization or location changes.
///
/// ✅ Responsibilities:
///   - Provide the current EffectivePolicy
///   - Fetch from repository on context changes
///   - Cache until organization/location/version changes
///
/// ❌ Does NOT:
///   - Evaluate policy rules
///   - Import UI
///   - Contain business logic
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/policies/domain/effective_policy.dart';
import 'package:famhub_app/core/policies/infrastructure/policy_repository.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';

/// ============================================================
/// PROVIDER: POLICY REPOSITORY
/// ============================================================
///
/// Provides the policy repository implementation.
/// Swap this to SupabasePolicyRepository when backend is ready.
/// ============================================================
final policyRepositoryProvider = Provider<PolicyRepository>((ref) {
  // TODO: Replace with SupabasePolicyRepository when backend is ready.
  return const InMemoryPolicyRepository();
});

/// ============================================================
/// PROVIDER: EFFECTIVE POLICY
/// ============================================================
///
/// Provides the effective policy for the current organization
/// and location.
///
/// Fetches from repository when context changes.
/// Returns null when context is still loading.
/// Cached until organization or location changes.
/// ============================================================
final effectivePolicyProvider = FutureProvider<EffectivePolicy?>((ref) async {
  final context = ref.watch(contextProvider);

  if (context.isLoading || context.entityId == null) {
    return null;
  }

  final organizationId = context.entityId!;
  final locationId = context.entityId!; // TODO: Use actual location ID when available

  final repository = ref.watch(policyRepositoryProvider);
  return repository.getEffectivePolicy(
    organizationId: organizationId,
    locationId: locationId,
  );
});

/// ============================================================
/// PROVIDER: POLICY VERSION
/// ============================================================
///
/// Provides the current policy version for change detection.
/// ============================================================
final policyVersionProvider = Provider<String?>((ref) {
  final asyncPolicy = ref.watch(effectivePolicyProvider);
  return asyncPolicy.whenOrNull(
    data: (policy) => policy?.version,
  );
});
