import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/feature_flags/application/providers/feature_access_provider.dart';
class FeatureGate extends ConsumerWidget {
  final String featureKey;
  final Widget child;
  final Widget? lockedWidget;
  final Widget? maintenanceWidget;
  final Widget? adminOnlyWidget;

  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
    this.lockedWidget,
    this.maintenanceWidget,
    this.adminOnlyWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessAsync = ref.watch(featureAccessProvider(featureKey));

    return accessAsync.when(
      data: (canAccess) {
        if (canAccess) {
    return child;
  }
        return lockedWidget ?? const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
}
}
