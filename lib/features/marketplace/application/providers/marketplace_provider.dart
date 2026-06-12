import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/listing.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../infrastructure/services/marketplace_service.dart';

/// Marketplace async provider.
/// Returns AsyncValue<List<Listing>> to support loading/error/data states.
final marketplaceProvider = AsyncNotifierProvider<MarketplaceController, List<Listing>>(
  MarketplaceController.new,
);

class MarketplaceController extends AsyncNotifier<List<Listing>> {
  @override
  Future<List<Listing>> build() async {
    final repo = MarketplaceRepository(MarketplaceService());
    return repo.fetchListings();
  }

  Future<void> load() async {
    final repo = MarketplaceRepository(MarketplaceService());
    state = AsyncValue.data(await repo.fetchListings());
  }
}