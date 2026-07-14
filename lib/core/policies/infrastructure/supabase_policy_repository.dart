/// ============================================================
/// SUPABASE POLICY REPOSITORY — BACKEND POLICY RESOLUTION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/infrastructure/ = infrastructure layer
///
/// The SupabasePolicyRepository calls the backend RPC/view to
/// retrieve the effective policy for an organization and location.
///
/// No evaluation. No filtering. Backend owns policy resolution.
///
/// ✅ Responsibilities:
///   - Call backend RPC to resolve effective policy
///   - Map backend response to EffectivePolicy model
///   - Handle errors gracefully
///
/// ❌ Does NOT:
///   - Evaluate policies
///   - Apply business logic
///   - Import UI
/// ============================================================
library;

import 'package:famhub_app/core/policies/domain/effective_policy.dart';
import 'package:famhub_app/core/policies/infrastructure/policy_repository.dart';
import 'package:famhub_app/core/services/supabase_service.dart';

/// ============================================================
/// SUPABASE POLICY REPOSITORY
/// ============================================================
///
/// Fetches effective policies from the backend using Supabase RPC.
///
/// Expected backend RPC: get_effective_policy
/// Params: p_organization_id, p_location_id
/// Returns: { rules: {...}, version: '...', resolved_at: '...' }
/// ============================================================
class SupabasePolicyRepository implements PolicyRepository {
  final SupabaseService _supabase;

  const SupabasePolicyRepository({required SupabaseService supabase})
      : _supabase = supabase;

  @override
  Future<EffectivePolicy> getEffectivePolicy({
    required String organizationId,
    required String locationId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_effective_policy',
        params: {
          'p_organization_id': organizationId,
          'p_location_id': locationId,
        },
      );

      if (response == null) {
        return _fallbackPolicy(organizationId, locationId);
      }

      final data = response as Map<String, dynamic>;

      return EffectivePolicy(
        rules: Map<String, dynamic>.from(data['rules'] ?? {}),
        locationId: locationId,
        organizationId: organizationId,
        version: data['version']?.toString() ?? '1.0',
        resolvedAt: data['resolved_at'] != null
            ? DateTime.tryParse(data['resolved_at'].toString()) ??
                DateTime.now()
            : DateTime.now(),
      );
    } catch (e) {
      // Log and return fallback on error
      // ignore: avoid_print
      print('[POLICY] Failed to fetch effective policy: $e');
      return _fallbackPolicy(organizationId, locationId);
    }
  }

  @override
  Stream<EffectivePolicy> watchEffectivePolicy({
    required String organizationId,
    required String locationId,
  }) async* {
    // Initial fetch
    yield await getEffectivePolicy(
      organizationId: organizationId,
      locationId: locationId,
    );

    // TODO: Listen to realtime changes on policy table
    // when backend implements realtime policy updates.
    //
    // final channel = _supabase.createChannel('policy:$organizationId:$locationId');
    // channel.onPostgresChanges(
    //   event: PostgresChangeEvent.all,
    //   schema: 'public',
    //   table: 'effective_policies',
    //   filter: PostgresChangeFilter(
    //     column: 'organization_id',
    //     operator: 'eq',
    //     value: organizationId,
    //   ),
    //   callback: (payload) {
    //     // Re-fetch and yield updated policy
    //   },
    // );
  }

  /// ============================================================
  /// FALLBACK POLICY
  /// ============================================================
  ///
  /// Returns safe defaults when the backend is unreachable.
  /// Never fails open — all rules default to disabled.
  /// ============================================================
  EffectivePolicy _fallbackPolicy(
    String organizationId,
    String locationId,
  ) {
    return EffectivePolicy(
      rules: {
        'workflow.execution': false,
        'inventory.tracking': false,
        'marketplace.selling': false,
        'marketplace.buying': false,
        'marketplace.orders': false,
        'upload.max_images': 3,
        'traceability.enabled': false,
        'finance.recording': false,
        'analytics.enabled': false,
        'ai.assistant': false,
        'staff.management': false,
        'export.certification': false,
        'coldchain.enabled': false,
        'logistics.enabled': false,
        'contract.farming': false,
        'region.restriction': <String>[],
      },
      locationId: locationId,
      organizationId: organizationId,
      version: 'fallback',
    );
  }
}
