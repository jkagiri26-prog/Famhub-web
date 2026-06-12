import 'package:famhub_app/core/subscription/domain/models/subscription_tier.dart';

class SubscriptionService {
  static bool hasAccess({
    required SubscriptionTier userTier,
    required SubscriptionTier requiredTier,
  }) {
    return userTier.index >= requiredTier.index;
  }
}