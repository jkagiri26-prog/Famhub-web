import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_entitlements.dart';

class SubscriptionEntitlementsRepository {
  const SubscriptionEntitlementsRepository();

  static const String resolveRpc = 'resolve_my_subscription_entitlements';

  Future<SubscriptionEntitlements> resolve({String? entityId}) async {
    final response = await SupabaseService.instance.client
        .schema('system')
        .rpc(resolveRpc, params: {'p_entity_id': entityId});
    if (response is! List) return SubscriptionEntitlements.empty;
    return SubscriptionEntitlements.fromRows(
      response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false),
    );
  }
}
