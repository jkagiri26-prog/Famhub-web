import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_tier.dart';

/// Subscription tier notifier
class SubscriptionNotifier extends Notifier<SubscriptionTier> {
  @override
  SubscriptionTier build() => SubscriptionTier.free;

  void setTier(SubscriptionTier tier) => state = tier;
    void upgrade() => state = SubscriptionTier.basic;
  void downgrade() => state = SubscriptionTier.free;
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionTier>(
  SubscriptionNotifier.new,
);
