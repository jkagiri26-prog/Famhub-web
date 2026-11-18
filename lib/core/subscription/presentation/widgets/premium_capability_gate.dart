import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/router/route_names.dart';
import 'package:famhub_app/core/subscription/application/providers/subscription_entitlements_provider.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_entitlements.dart';

/// Reusable UI boundary for premium capabilities.
///
/// The canonical [subscriptionEntitlementsProvider] is the only entitlement
/// source. Missing, loading, error, expired or capability-less states fail
/// closed. Core/free features must not use this gate.
class PremiumCapabilityGate extends ConsumerWidget {
  const PremiumCapabilityGate({
    super.key,
    required this.capabilityKey,
    required this.title,
    required this.child,
    this.message =
        'This premium feature is part of a Vunio subscription. Core Vunio '
        'functionality remains available without it.',
  });

  final String capabilityKey;
  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlements = ref
        .watch(subscriptionEntitlementsProvider)
        .asData
        ?.value;
    if (entitlements != null &&
        entitlements.verified &&
        entitlements.isActive &&
        entitlements.hasCapability(capabilityKey)) {
      return child;
    }
    return _LockedCapabilityCard(title: title, message: message);
  }
}

class _LockedCapabilityCard extends StatelessWidget {
  const _LockedCapabilityCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => context.go(AppRoutes.subscription),
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('View subscription plans'),
          ),
        ],
      ),
    );
  }
}
