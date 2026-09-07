/// ============================================================
/// BUSINESS HUB — MY BUSINESSES PROVIDER
/// ============================================================
///
/// Loads the business/entity records available to the current user
/// from `core.entities` (RLS-scoped; ownership resolved server-side).
///
/// Watches [businessHubRepositoryProvider], so it transparently rebuilds
/// when the user's auth state flips between the demo and live
/// repositories.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/business_hub/domain/entities/business_entity.dart';
import 'business_hub_repository_provider.dart';

final myBusinessesProvider =
    FutureProvider<List<BusinessEntity>>((ref) async {
  final repo = ref.watch(businessHubRepositoryProvider);
  return repo.fetchMyBusinesses();
});
