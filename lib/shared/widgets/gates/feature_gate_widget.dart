import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/access/access_decision_engine.dart';
import '../../core/context_engine/providers/ui_context_provider.dart';
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
    final appContext = ref.watch(uiContextProvider);
    final subscription = ref.watch(subscriptionProvider);

    final engine = ref.read(accessDecisionEngineProvider);

    final decision = engine.evaluate(
      featureKey: featureKey,
      permission: permission,
      role: appContext.role,
      userTier: subscription,
    );

    if (!decision.allowed) {
      return const SizedBox.shrink();
    }

    return child;
  }
}