/// ============================================================
/// MARKET PRICES — REMOTE DATA SOURCE
/// ============================================================
///
/// Supabase access for Market Prices, following the established
/// repository/service/data-source pattern. Reads:
///   - `marketplace.list_markets`              (RPC, market + hierarchy)
///   - `marketplace.daily_market_prices`       (aggregated, verified)
///   - `marketplace.market_prices`             (raw verified observations)
///   - `marketplace.price_favourites`          (profile-specific, RLS)
///
/// No cross-schema PostgREST embeds (stale schema cache). Referenced display
/// names (item/variant/unit/location) are resolved via the existing
/// [MarketplaceRemoteDataSource] batched lookups in the repository layer.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/marketplace/domain/models/market_prices_filter.dart';

class MarketPricesRemoteDataSource {
  final SupabaseClient _client;

  MarketPricesRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Resolve a single feature flag from `system.feature_flags`.
  ///
  /// Used to gate the Market Prices capability on
  /// `marketplace.market_prices`.
  Future<bool> isFeatureEnabled(String flagKey) async {
    try {
      final response = await _client
          .schema('system')
          .from('feature_flags')
          .select('flag_key, is_enabled')
          .eq('flag_key', flagKey)
          .maybeSingle();
      if (response == null) return false;
      return response['is_enabled'] == true;
    } on PostgrestException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch available markets and their canonical location hierarchy via the
  /// `marketplace.list_markets` RPC.
  ///
  /// The RPC result is parsed defensively across common field names; the
  /// client never invents location data.
  Future<List<Map<String, dynamic>>> listMarkets() async {
    final response = await _client
        .schema('marketplace')
        .rpc('list_markets', params: const {});

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    if (response is Map<String, dynamic>) {
      // Some backends return { data: [...] }.
      final data = response['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
      return [response];
    }
    return const [];
  }

  /// Aggregated (verified) daily prices for the given filter.
  Future<List<Map<String, dynamic>>> fetchDailyPrices({
    required MarketPricesFilter filter,
  }) async {
    var query = _client
        .schema('marketplace')
        .from('daily_market_prices')
        .select();

    if (filter.marketId != null && filter.marketId!.isNotEmpty) {
      query = query.eq('market_id', filter.marketId!);
    }
    if (filter.locationId != null && filter.locationId!.isNotEmpty) {
      query = query.eq('location_id', filter.locationId!);
    }
    if (filter.itemId != null && filter.itemId!.isNotEmpty) {
      query = query.eq('item_id', filter.itemId!);
    }
    if (filter.variantId != null && filter.variantId!.isNotEmpty) {
      query = query.eq('variant_id', filter.variantId!);
    }
    if (filter.unitId != null && filter.unitId!.isNotEmpty) {
      query = query.eq('unit_id', filter.unitId!);
    }
    if (filter.priceType != null && filter.priceType!.isNotEmpty) {
      query = query.eq('price_type', filter.priceType!);
    }
    if (filter.currency != null && filter.currency!.isNotEmpty) {
      query = query.eq('currency', filter.currency!);
    }
    if (filter.recordedOn != null) {
      query = query.eq('recorded_on', filter.recordedOn!.toIso8601String());
    }

    final response = await query.order('recorded_on', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Raw VERIFIED observations (`marketplace.market_prices`), for the UI
  /// where observation-level detail is required. Never returns draft /
  /// submitted / rejected / correction-requested rows.
  Future<List<Map<String, dynamic>>> fetchVerifiedObservations({
    required MarketPricesFilter filter,
  }) async {
    var query = _client
        .schema('marketplace')
        .from('market_prices')
        .select()
        .eq('status', 'verified');

    if (filter.marketId != null && filter.marketId!.isNotEmpty) {
      query = query.eq('market_id', filter.marketId!);
    }
    if (filter.locationId != null && filter.locationId!.isNotEmpty) {
      query = query.eq('location_id', filter.locationId!);
    }
    if (filter.variantId != null && filter.variantId!.isNotEmpty) {
      query = query.eq('variant_id', filter.variantId!);
    }
    if (filter.itemId != null && filter.itemId!.isNotEmpty) {
      query = query.eq('item_id', filter.itemId!);
    }

    final response = await query.order('recorded_on', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Profile-specific favourites (RLS-scoped).
  Future<List<Map<String, dynamic>>> fetchFavourites() async {
    final response = await _client
        .schema('marketplace')
        .from('price_favourites')
        .select();
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Add a profile-specific favourite. The profile is derived by RLS.
  Future<void> addFavourite({
    String? marketId,
    String? locationId,
    String? itemId,
    String? variantId,
  }) async {
    await _client.schema('marketplace').from('price_favourites').insert({
      if (marketId != null && marketId.isNotEmpty) 'market_id': marketId,
      if (locationId != null && locationId.isNotEmpty)
        'location_id': locationId,
      if (itemId != null && itemId.isNotEmpty) 'item_id': itemId,
      if (variantId != null && variantId.isNotEmpty) 'variant_id': variantId,
    });
  }

  /// Remove a profile-specific favourite.
  Future<void> removeFavourite({required String favouriteId}) async {
    await _client
        .schema('marketplace')
        .from('price_favourites')
        .delete()
        .eq('id', favouriteId);
  }
}
