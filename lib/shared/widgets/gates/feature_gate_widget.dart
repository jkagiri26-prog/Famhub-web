import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/access/access_decision_engine.dart';
import '../../core/context/context_provider.dart';
import '../../core/subscription/application/providers/subscription_provider.dart';

class FeatureGate extends ConsumerWidget {
  final String featureKey;
  final String permission;
  final Widget child;

  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.permission,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContext = ref.watch(contextProvider);
    final subscription = ref.watch(subscriptionProvider);

    final allowed = AccessDecisionEngine.canAccess(
      featureKey: featureKey,
      permission: permission,
      role: appContext.role.activeRole,
      userTier: subscription,
    );

    if (!allowed) {
      return const SizedBox.shrink();
    }

    return child;
  }
}