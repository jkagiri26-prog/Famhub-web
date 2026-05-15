import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/services/access_policy_service.dart';
import '../../domain/models/access_policy.dart';

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
    final response =
        await client.rpc('get_access_policy');

    if (response == null) return;

    final data = response as Map<String, dynamic>;

    final updatedPolicy = AccessPolicy(
      rolePermissions:
          Map<String, List<String>>.from(data['role_permissions']),
      featureTiers: Map<String, String>.from(data['feature_tiers']),
    );

    service.setPolicy(updatedPolicy);
  }
}