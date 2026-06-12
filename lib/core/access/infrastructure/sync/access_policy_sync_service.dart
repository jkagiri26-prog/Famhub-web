import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/services/access_policy_service.dart';
import '../../domain/models/access_policy.dart';
import '../../../subscription/domain/models/subscription_tier.dart';

class AccessPolicySyncService {
  final SupabaseClient client;
  final AccessPolicyService service;

  AccessPolicySyncService({
    required this.client,
    required this.service,
  });

  void startListening() {
    client
        .from('access_policy_changes')
        .stream(primaryKey: ['id'])
        .listen((data) async {
      await _refreshPolicy();
    });
  }

  Future<void> _refreshPolicy() async {
    final response = await client.rpc('get_access_policy');

    if (response == null) return;

    if (response is! Map<String, dynamic>) return;

    final data = response;

    final rolePermissionsRaw =
        data['role_permissions'] as Map<String, dynamic>? ?? {};

    final featureTiersRaw =
        data['feature_tiers'] as Map<String, dynamic>? ?? {};

    final updatedPolicy = AccessPolicy(
      rolePermissions: rolePermissionsRaw.map(
        (key, value) => MapEntry(
          key,
          List<String>.from(value as List),
        ),
      ),
      featureTiers: featureTiersRaw.map(
        (key, value) => MapEntry(
          key,
          SubscriptionTier.values.firstWhere(
            (e) => e.name == value,
            orElse: () => SubscriptionTier.free,
          ),
        ),
      ),
    );

    service.setPolicy(updatedPolicy);
  }
}