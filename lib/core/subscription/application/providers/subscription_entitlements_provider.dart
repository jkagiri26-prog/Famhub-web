import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_entitlements.dart';
import 'package:famhub_app/core/subscription/infrastructure/repositories/subscription_entitlements_repository.dart';

final subscriptionEntitlementsRepositoryProvider =
    Provider<SubscriptionEntitlementsRepository>(
      (ref) => const SubscriptionEntitlementsRepository(),
    );

/// One shared entitlement provider for every Vunio workspace/module.
final subscriptionEntitlementsProvider =
    FutureProvider<SubscriptionEntitlements>((ref) async {
      final context = ref.watch(contextProvider);
      if (context.isGuest) return SubscriptionEntitlements.unverified;

      final result = await ref
          .watch(subscriptionEntitlementsRepositoryProvider)
          .resolve(entityId: context.entityId);

      final end = result.endDate?.toUtc();
      if (end != null && result.isActive) {
        final delay = end.difference(DateTime.now().toUtc());
        if (delay > Duration.zero) {
          final timer = Timer(delay, () => ref.invalidateSelf());
          ref.onDispose(timer.cancel);
        }
      }
      return result;
    });
