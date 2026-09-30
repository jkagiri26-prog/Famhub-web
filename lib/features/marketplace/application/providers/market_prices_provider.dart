/// ============================================================
/// MARKET PRICES PROVIDERS (APPLICATION LAYER)
/// ============================================================
///
/// Providers for Market Prices — gated by the `marketplace.market_prices`
/// feature flag and backed by the MarketPricesRepository.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/daily_market_price.dart';
import '../../domain/entities/market.dart';
import '../../domain/entities/price_favourite.dart';
import '../../domain/models/market_prices_filter.dart';
import '../../domain/repositories/market_prices_repository.dart';
import '../../infrastructure/data_sources/market_prices_remote_data_source.dart';
import '../../infrastructure/repositories/market_prices_repository_impl.dart';
import 'marketplace_provider.dart' show marketplaceRemoteDataSourceProvider;

// ── Data source / repository ────────────────────────────────

final marketPricesRemoteDataSourceProvider =
    Provider<MarketPricesRemoteDataSource>((ref) {
  return MarketPricesRemoteDataSource();
});

final marketPricesRepositoryProvider =
    Provider<MarketPricesRepository>((ref) {
  final dataSource = ref.watch(marketPricesRemoteDataSourceProvider);
  final reference = ref.watch(marketplaceRemoteDataSourceProvider);
  return MarketPricesRepositoryImpl(dataSource, reference);
});

// ── Feature flag gate: marketplace.market_prices ────────────

/// Whether the `marketplace.market_prices` feature flag is enabled.
/// Read from `system.feature_flags` (no local flag is created).
final marketPricesFeatureEnabledProvider = FutureProvider<bool>((ref) async {
  final dataSource = ref.watch(marketPricesRemoteDataSourceProvider);
  return dataSource.isFeatureEnabled('marketplace.market_prices');
});

// ── Markets (geographic reference) ──────────────────────────

final marketsProvider = FutureProvider<List<Market>>((ref) async {
  final repo = ref.watch(marketPricesRepositoryProvider);
  return repo.listMarkets();
});

// ── Filter state (geographic scope only) ─────────────────────
//
// Item / variant / unit / price-type / currency refinement is applied
// client-side against the geo-scoped (backend-rolled-up) result.

class MarketPricesFilterState {
  final String? countyId;
  final String? subCountyId;
  final String? wardId;
  final String? marketId;

  const MarketPricesFilterState({
    this.countyId,
    this.subCountyId,
    this.wardId,
    this.marketId,
  });

  bool get hasSelection => countyId != null;

  MarketPricesFilter toFilter() {
    if (marketId != null && marketId!.isNotEmpty) {
      return MarketPricesFilter(marketId: marketId);
    }
    if (wardId != null && wardId!.isNotEmpty) {
      return MarketPricesFilter(locationId: wardId);
    }
    if (subCountyId != null && subCountyId!.isNotEmpty) {
      return MarketPricesFilter(locationId: subCountyId);
    }
    if (countyId != null && countyId!.isNotEmpty) {
      return MarketPricesFilter(locationId: countyId);
    }
    return const MarketPricesFilter();
  }

  MarketPricesFilterState copyWith({
    String? countyId,
    String? subCountyId,
    String? wardId,
    String? marketId,
    bool clearCountyId = false,
    bool clearSubCountyId = false,
    bool clearWardId = false,
    bool clearMarketId = false,
  }) {
    return MarketPricesFilterState(
      countyId: clearCountyId ? null : (countyId ?? this.countyId),
      subCountyId:
          clearSubCountyId ? null : (subCountyId ?? this.subCountyId),
      wardId: clearWardId ? null : (wardId ?? this.wardId),
      marketId: clearMarketId ? null : (marketId ?? this.marketId),
    );
  }
}

class MarketPricesFilterNotifier extends Notifier<MarketPricesFilterState> {
  @override
  MarketPricesFilterState build() => const MarketPricesFilterState();

  void selectCounty(String? id) {
    state = MarketPricesFilterState(countyId: id);
  }

  void selectSubCounty(String? id) {
    state = state.copyWith(
      subCountyId: id,
      clearWardId: true,
      clearMarketId: true,
    );
  }

  void selectWard(String? id) {
    state = state.copyWith(wardId: id, clearMarketId: true);
  }

  void selectMarket(String? id) {
    state = state.copyWith(marketId: id);
  }

  void reset() => state = const MarketPricesFilterState();
}

final marketPricesFilterProvider =
    NotifierProvider<MarketPricesFilterNotifier, MarketPricesFilterState>(
  MarketPricesFilterNotifier.new,
);

// ── Prices (aggregated, verified) ───────────────────────────

final dailyMarketPricesProvider =
    FutureProvider<List<DailyMarketPrice>>((ref) async {
  final filter = ref.watch(marketPricesFilterProvider).toFilter();
  final repo = ref.watch(marketPricesRepositoryProvider);
  return repo.fetchDailyPrices(filter: filter);
});

// ── Favourites ──────────────────────────────────────────────

final priceFavouritesProvider =
    FutureProvider<List<PriceFavourite>>((ref) async {
  final repo = ref.watch(marketPricesRepositoryProvider);
  return repo.fetchFavourites();
});

class PriceFavouritesController extends Notifier<void> {
  @override
  void build() {}

  Future<void> add({
    String? marketId,
    String? locationId,
    String? itemId,
    String? variantId,
  }) async {
    final repo = ref.read(marketPricesRepositoryProvider);
    await repo.addFavourite(
      marketId: marketId,
      locationId: locationId,
      itemId: itemId,
      variantId: variantId,
    );
    ref.invalidate(priceFavouritesProvider);
  }

  Future<void> remove(String favouriteId) async {
    final repo = ref.read(marketPricesRepositoryProvider);
    await repo.removeFavourite(favouriteId: favouriteId);
    ref.invalidate(priceFavouritesProvider);
  }
}

final priceFavouritesControllerProvider =
    NotifierProvider<PriceFavouritesController, void>(
  PriceFavouritesController.new,
);
