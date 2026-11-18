import 'package:flutter/material.dart';

import 'package:famhub_app/core/subscription/presentation/widgets/premium_capability_gate.dart';

/// Existing canonical premium Farm feature key from FeatureRegistry.
const String kFarmPremiumInsightsCapability = 'farm_analytics';

/// Gates only premium Farm insights; core Farm Management remains free.
class FarmPremiumInsightsGate extends StatelessWidget {
  const FarmPremiumInsightsGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumCapabilityGate(
      capabilityKey: kFarmPremiumInsightsCapability,
      title: 'Advanced farm insights',
      message:
          'Personalised farm recommendations and premium insights are part of '
          'a Vunio subscription. Core Farm Management remains available.',
      child: child,
    );
  }
}
