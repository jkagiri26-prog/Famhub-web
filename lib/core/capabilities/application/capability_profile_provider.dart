/// ============================================================
/// CAPABILITY PROFILE PROVIDER — ORGANIZATION PROFILE SOURCE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/application/ = capability application layer
///
/// This provider is the single source of truth for the current
/// organization's capability profile.
///
/// In Stage 3, the profile is derived from the organization context
/// (entity type, etc.). In future stages, this will come from the
/// backend (organization_capabilities table).
///
/// ✅ Responsibilities:
///   - Provide the current CapabilityProfile
///   - Derive from EntityContext initially
///   - Support future backend persistence
///
/// ❌ Does NOT:
///   - Perform capability evaluation
///   - Import UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/capabilities/domain/capability_profile.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';

/// ============================================================
/// PROVIDER: CAPABILITY PROFILE
/// ============================================================
///
/// Provides the capability profile for the current organization.
///
/// Currently derives from the EntityContext (entity type).
/// Future: fetch from backend organization_capabilities table.
///
/// Returns null when context is still loading.
/// ============================================================
final capabilityProfileProvider = Provider<CapabilityProfile?>((ref) {
  final context = ref.watch(contextProvider);

  if (context.isLoading) return null;

  // ── Future backend alignment ──
  // In production, this provider will fetch the capability profile
  // from the backend using the organization ID:
  //
  //   final repo = ref.watch(organizationCapabilityRepositoryProvider);
  //   final profile = await repo.getProfile(organizationId);
  //   return profile;
  //
  // For now, derive from entity context.
  return _deriveProfileFromContext(context);
});

/// ============================================================
/// DERIVE PROFILE FROM ENTITY CONTEXT (STAGE 3)
/// ============================================================
///
/// Maps the current entity context to a capability profile.
///
/// This is a TEMPORARY mapping until the backend capability
/// system is implemented. It maps:
///   - No entity / guest → empty profile (no capabilities)
///   - Individual farmer → basic farming capabilities
///   - Aggregator → extended capabilities with logistics
///   - Enterprise → full capabilities
///
/// 🚨 WARNING:
///   This mapping MUST be replaced with backend-driven profiles.
///   Do NOT add new entity types here. Instead, extend the
///   backend organization_capabilities table.
/// ============================================================
CapabilityProfile _deriveProfileFromContext(EntityContext context) {
  final orgId = context.entityId ?? 'anonymous';

  if (context.isGuest || context.entityId == null) {
    return CapabilityProfileFactory.empty(orgId);
  }

  // TODO: Replace with backend-driven capability profile fetch.
  // The entity type mapping below is temporary for Stage 3.
  // In production, this logic lives in the backend
  // (organization_capabilities table).
  switch (context.role) {
    case 'farmer':
    case 'individual':
      return CapabilityProfileFactory.basicFarmer(orgId);

    case 'aggregator':
      return CapabilityProfileFactory.aggregator(orgId);

    case 'enterprise':
    case 'commercial':
    case 'exporter':
    case 'processor':
      return CapabilityProfileFactory.enterprise(orgId);

    case 'cooperative':
      // Cooperatives typically have aggregator-like capabilities
      return CapabilityProfileFactory.aggregator(orgId);

    default:
      return CapabilityProfileFactory.basicFarmer(orgId);
  }
}
