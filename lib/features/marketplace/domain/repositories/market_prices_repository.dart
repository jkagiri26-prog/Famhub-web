import '../entities/daily_market_price.dart';
import '../entities/market.dart';
import '../entities/price_favourite.dart';
import '../models/market_prices_filter.dart';

/// Abstract repository contract for Market Prices reads.
///
/// Market lookup uses the `marketplace.list_markets` RPC. Price reads use
/// the documented backend objects:
///   - `marketplace.daily_market_prices`  (aggregated, verified)
///   - `marketplace.market_prices`        (raw, verified observations)
///   - `marketplace.price_favourites`     (profile-specific, RLS-scoped)
///
/// The frontend NEVER computes geographic averages from market rows — it
/// uses the backend's observation-weighted rollups.
abstract class MarketPricesRepository {
  /// Available markets and their canonical location hierarchy.
  Future<List<Market>> listMarkets();

  /// Aggregated (verified) daily prices for the given filter.
  Future<List<DailyMarketPrice>> fetchDailyPrices({
    required MarketPricesFilter filter,
  });

  /// Profile-specific favourites (RLS-scoped).
  Future<List<PriceFavourite>> fetchFavourites();

  /// Add a profile-specific favourite.
  Future<void> addFavourite({
    String? marketId,
    String? locationId,
    String? itemId,
    String? variantId,
  });

  /// Remove a profile-specific favourite.
  Future<void> removeFavourite({required String favouriteId});
}
