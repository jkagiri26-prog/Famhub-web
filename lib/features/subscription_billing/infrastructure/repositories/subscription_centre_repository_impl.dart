import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/subscription_billing/domain/models/subscription_centre_state.dart';
import 'package:famhub_app/features/subscription_billing/domain/repositories/subscription_centre_repository.dart';

class SubscriptionCentreRepositoryImpl implements SubscriptionCentreRepository {
  const SubscriptionCentreRepositoryImpl();

  static const String centreStateRpc = 'get_my_subscription_centre';
  static const String billingFunction = 'subscription-billing';

  @override
  Future<SubscriptionCentreState> fetchState() async {
    final response = await SupabaseService.instance.client
        .schema('system')
        .rpc(centreStateRpc);
    if (response is! List) return SubscriptionCentreState.empty;
    return SubscriptionCentreState(
      entries: response
          .whereType<Map>()
          .map(
            (row) => SubscriptionCentreEntry.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .where((entry) => entry.subscriptionCycleId.isNotEmpty)
          .toList(growable: false),
    );
  }

  @override
  Future<SubscriptionInitiation> initiatePayment({
    required String subscriptionCycleId,
    required String phone,
    required String idempotencyKey,
  }) async {
    try {
      final response = await SupabaseService.instance.client.functions.invoke(
        billingFunction,
        body: {
          'action': 'initiate',
          'subscriptionCycleId': subscriptionCycleId,
          'phone': phone,
          'idempotencyKey': idempotencyKey,
        },
      );
      final data = response.data;
      if (data is! Map || data['ok'] != true) {
        throw const SubscriptionCentreError('Subscription payment failed.');
      }
      return SubscriptionInitiation.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (error) {
      if (error.status == 503 &&
          _contains(error, 'mpesa_provider_not_configured')) {
        throw const SubscriptionProviderUnavailable();
      }
      if (error.status == 503 &&
          _contains(error, 'mpesa_provider_outcome_unknown')) {
        throw const SubscriptionOutcomeUnknown();
      }
      if (error.status == 502 || _contains(error, 'mpesa_provider_rejected')) {
        throw const SubscriptionPaymentRejected();
      }
      if (_contains(error, 'subscription_payment_not_retryable')) {
        throw const SubscriptionPaymentRejected();
      }
      throw const SubscriptionCentreError('Subscription payment failed.');
    }
  }

  static bool _contains(FunctionException error, String value) {
    return error.details?.toString().contains(value) == true;
  }
}
