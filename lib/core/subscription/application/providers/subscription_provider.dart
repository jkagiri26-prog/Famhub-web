import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/subscription_tier.dart';

final subscriptionProvider =
    StateProvider<SubscriptionTier>((ref) {
  return SubscriptionTier.free; // default fallback
});