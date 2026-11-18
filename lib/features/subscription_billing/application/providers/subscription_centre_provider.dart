import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/subscription_billing/domain/models/subscription_centre_state.dart';
import 'package:famhub_app/features/subscription_billing/domain/repositories/subscription_centre_repository.dart';
import 'package:famhub_app/features/subscription_billing/infrastructure/repositories/subscription_centre_repository_impl.dart';

final subscriptionCentreRepositoryProvider =
    Provider<SubscriptionCentreRepository>(
      (ref) => const SubscriptionCentreRepositoryImpl(),
    );

final subscriptionCentreStateProvider = FutureProvider<SubscriptionCentreState>(
  (ref) => ref.watch(subscriptionCentreRepositoryProvider).fetchState(),
);
