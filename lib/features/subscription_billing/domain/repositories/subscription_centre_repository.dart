import '../models/subscription_centre_state.dart';

/// Read/initiation contract for the universal Subscription Centre.
///
/// It never confirms payments or activates entitlements. Confirmation remains
/// in the backend subscription-billing callback boundary and Finance.
abstract class SubscriptionCentreRepository {
  Future<SubscriptionCentreState> fetchState();

  Future<SubscriptionInitiation> initiatePayment({
    required String subscriptionCycleId,
    required String phone,
    required String idempotencyKey,
  });
}
