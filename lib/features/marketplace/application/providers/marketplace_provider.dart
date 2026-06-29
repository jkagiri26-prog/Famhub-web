import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/listing.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../domain/enums/listing_status.dart';
import '../../infrastructure/data_sources/marketplace_remote_data_source.dart';
import '../../infrastructure/repositories/marketplace_repository_impl.dart';

/// ============================================================
/// DATA SOURCE LAYER
/// ============================================================
final marketplaceRemoteDataSourceProvider =
    Provider<MarketplaceRemoteDataSource>((ref) {
  return MarketplaceRemoteDataSource();
});

/// ============================================================
/// REPOSITORY LAYER
/// ============================================================
final marketplaceRepositoryProvider =
    Provider<MarketplaceRepository>((ref) {
  final dataSource = ref.watch(marketplaceRemoteDataSourceProvider);
  return MarketplaceRepositoryImpl(dataSource);
});

/// ============================================================
/// MARKETPLACE CONTROLLER (ASYNC NOTIFIER)
/// ============================================================
final marketplaceProvider =
    AsyncNotifierProvider<MarketplaceController, List<Listing>>(
  MarketplaceController.new,
);

class MarketplaceController extends AsyncNotifier<List<Listing>> {
  MarketplaceRepository get _repo =>
      ref.read(marketplaceRepositoryProvider);

  @override
  Future<List<Listing>> build() async {
    return _safeFetch();
  }

  Future<List<Listing>> _safeFetch() async {
    try {
      return await _repo.fetchListings();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> load() async {
    state = const AsyncLoading();

    try {
      final data = await _repo.fetchListings();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> createListing(Map<String, dynamic> payload) async {
    await _repo.createListing(payload);
    ref.invalidateSelf();
  }

  Future<void> updateListing(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await _repo.updateListing(id, payload);

    ref.invalidateSelf();
    ref.invalidate(listingDetailsProvider(id));
  }

  Future<void> archiveListing(String id) async {
    await _repo.archiveListing(id);

    ref.invalidateSelf();
    ref.invalidate(listingDetailsProvider(id));
  }

  Future<void> publishListing(String id) async {
    await _repo.publishListing(id);

    ref.invalidateSelf();
    ref.invalidate(listingDetailsProvider(id));
  }

  Future<void> updateInventory({
    required String listingId,
    double? availableQuantity,
    double? soldQuantity,
    double? reservedQuantity,
  }) async {
    await _repo.updateInventory(
      listingId: listingId,
      availableQuantity: availableQuantity,
      soldQuantity: soldQuantity,
      reservedQuantity: reservedQuantity,
    );

    ref.invalidateSelf();
    ref.invalidate(listingDetailsProvider(listingId));
  }
}

/// ============================================================
/// DETAIL PROVIDERS
/// ============================================================
final listingDetailsProvider =
    FutureProvider.family<Listing?, String>((ref, id) async {
  final repo = ref.read(marketplaceRepositoryProvider);
  return repo.fetchListingById(id);
});

final sellerListingsProvider =
    FutureProvider.family<List<Listing>, String>((ref, sellerId) async {
  final repo = ref.read(marketplaceRepositoryProvider);
  return repo.fetchListings(sellerId: sellerId);
});

final sellerStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, sellerId) async {
    final repo = ref.read(marketplaceRepositoryProvider);
    return repo.getSellerStats(sellerId);
  },
);