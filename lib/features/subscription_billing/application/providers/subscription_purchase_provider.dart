import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/subscription_billing/domain/models/subscription_purchase.dart';
import 'package:famhub_app/features/subscription_billing/domain/repositories/subscription_purchase_repository.dart';
import 'package:famhub_app/features/subscription_billing/infrastructure/repositories/subscription_purchase_repository_impl.dart';

final subscriptionPurchaseRepositoryProvider =
    Provider<SubscriptionPurchaseRepository>(
      (ref) => const SubscriptionPurchaseRepositoryImpl(),
    );

final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>(
  (ref) => ref.watch(subscriptionPurchaseRepositoryProvider).listPlans(),
);

/// Creates or reuses the authenticated caller's pending cycle for [planId].
///
/// The returned cycle id is the input for the existing `subscription-billing`
/// Edge Function in the next milestone.
final subscriptionPurchaseProvider =
    FutureProvider.family<SubscriptionPurchase, String>(
      (ref, planId) => ref
          .watch(subscriptionPurchaseRepositoryProvider)
          .createOrReusePurchase(planId: planId),
    );
