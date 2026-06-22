import 'package:famhub_app/core/access/domain/models/access_policy.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_tier.dart';

class AccessPolicyRepository {
  AccessPolicyRepository({
    SupabaseService? supabaseService,
  }) : _supabaseService =
            supabaseService ?? SupabaseService.instance;

  final SupabaseService _supabaseService;

  Future<AccessPolicy> fetchPolicy() async {
    try {
      final response = await _supabaseService.rpc(
        'get_access_policy',
      );

      if (response == null ||
          response is! Map<String, dynamic>) {
        return AccessPolicy.empty();
      }

      final rolePermissionsRaw =
          response['role_permissions']
                  as Map<String, dynamic>? ??
              {};

      final featureTiersRaw =
          response['feature_tiers']
                  as Map<String, dynamic>? ??
              {};

      final rolePermissions =
          rolePermissionsRaw.map(
        (key, value) => MapEntry(
          key,
          List<String>.from(
            (value as List?) ?? const [],
          ),
        ),
      );

      final featureTiers =
          featureTiersRaw.map(
        (key, value) {
          final tierString =
              value?.toString().toLowerCase();

          final tier =
              SubscriptionTier.values.firstWhere(
            (e) =>
                e.name.toLowerCase() ==
                tierString,
            orElse: () =>
                SubscriptionTier.free,
          );

          return MapEntry(key, tier);
        },
      );

      return AccessPolicy(
        rolePermissions: rolePermissions,
        featureTiers: featureTiers,
      );
    } catch (e) {
      throw AccessPolicyRepositoryException(
        'Failed to fetch access policy: $e',
      );
    }
  }
}

class AccessPolicyRepositoryException
    implements Exception {
  AccessPolicyRepositoryException(this.message);

  final String message;

  @override
  String toString() {
    return 'AccessPolicyRepositoryException: $message';
  }
}