import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_tier.dart';

final subscriptionProvider =
    StateProvider<SubscriptionTier>((ref) {
  return SubscriptionTier.free; // default fallback
});