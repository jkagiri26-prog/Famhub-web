import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/subscription_billing/domain/models/subscription_purchase.dart';
import 'package:famhub_app/features/subscription_billing/domain/repositories/subscription_purchase_repository.dart';

/// Supabase implementation of the customer-safe subscription purchase contract.
///
/// Only the authenticated catalog RPC and self-scoped create/reuse RPC are
/// called. No Finance confirmation, service-role key, amount, currency,
/// obligation id, or invoice id is sent from Flutter.
class SubscriptionPurchaseRepositoryImpl
    implements SubscriptionPurchaseRepository {
  const SubscriptionPurchaseRepositoryImpl();

  static const String listPlansRpc = 'list_subscription_plans';
  static const String createOrReusePurchaseRpc =
      'create_or_reuse_subscription_purchase';

  @override
  Future<List<SubscriptionPlan>> listPlans() async {
    final response = await SupabaseService.instance.client
        .schema('system')
        .rpc(listPlansRpc);

    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((row) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(row)))
        .where((plan) => plan.planId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<SubscriptionPurchase> createOrReusePurchase({
    required String planId,
  }) async {
    final response = await SupabaseService.instance.client
        .schema('system')
        .rpc(createOrReusePurchaseRpc, params: {'p_plan_id': planId});

    Map<dynamic, dynamic>? row;
    if (response is List) {
      for (final item in response) {
        if (item is Map) {
          row = item;
          break;
        }
      }
    } else if (response is Map) {
      row = response;
    }
    if (row == null) {
      throw Exception('Subscription purchase was not created.');
    }
    return SubscriptionPurchase.fromJson(Map<String, dynamic>.from(row));
  }
}
