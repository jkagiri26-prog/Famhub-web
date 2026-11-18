import '../models/subscription_purchase.dart';

/// Client contract for the customer-safe subscription purchase foundation.
///
/// It exposes only plan catalog reads and self-scoped create/reuse of a pending
/// subscription cycle. It never exposes Finance confirmation or service-role paths.
abstract class SubscriptionPurchaseRepository {
  Future<List<SubscriptionPlan>> listPlans();

  Future<SubscriptionPurchase> createOrReusePurchase({required String planId});
}
