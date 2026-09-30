/// ============================================================
/// MARKET PRICES — REPOSITORY IMPLEMENTATION
/// ============================================================
///
/// Maps raw backend rows to domain entities and resolves referenced
/// display names via the existing [MarketplaceRemoteDataSource] batched
/// lookups (no cross-schema PostgREST embeds).
/// ============================================================
library;

import 'package:famhub_app/features/marketplace/domain/entities/daily_market_price.dart';
import 'package:famhub_app/features/marketplace/domain/entities/market.dart';
import 'package:famhub_app/features/marketplace/domain/entities/price_favourite.dart';
import 'package:famhub_app/features/marketplace/domain/models/market_prices_filter.dart';
import 'package:famhub_app/features/marketplace/domain/repositories/market_prices_repository.dart';
import 'package:famhub_app/features/marketplace/infrastructure/data_sources/market_prices_remote_data_source.dart';
import 'package:famhub_app/features/marketplace/infrastructure/data_sources/marketplace_remote_data_source.dart';

class MarketPricesRepositoryImpl implements MarketPricesRepository {
  final MarketPricesRemoteDataSource dataSource;
  final MarketplaceRemoteDataSource referenceDataSource;

  MarketPricesRepositoryImpl(this.dataSource, this.referenceDataSource);

  @override
  Future<List<Market>> listMarkets() async {
    final rows = await dataSource.listMarkets();
    return rows.map((row) {
      return Market(
        id: _readString(row, ['id', 'market_id']) ?? '',
        name: _readString(row, ['market_name', 'name', 'market']) ?? 'Market',
        locationId: _readString(row, ['location_id', 'market_location_id']),
        countyId: _readString(row, ['county_id']),
        countyName: _readString(row, ['county_name', 'county']),
        subCountyId: _readString(row, ['sub_county_id', 'subcounty_id']),
        subCountyName:
            _readString(row, ['sub_county_name', 'subcounty_name', 'sub_county']),
        wardId: _readString(row, ['ward_id']),
        wardName: _readString(row, ['ward_name', 'ward']),
      );
    }).where((m) => m.id.isNotEmpty).toList();
  }

  @override
  Future<List<DailyMarketPrice>> fetchDailyPrices({
    required MarketPricesFilter filter,
  }) async {
    final rows = await dataSource.fetchDailyPrices(filter: filter);
    if (rows.isEmpty) return const [];

    // Resolve display names with batched lookups.
    final itemIds = _collect(rows, 'item_id');
    final variantIds = _collect(rows, 'variant_id');
    final unitIds = _collect(rows, 'unit_id');
    final locationIds = _collect(rows, 'location_id');

    Map<String, String> items = const {};
    Map<String, String> variants = const {};
    Map<String, String> units = const {};
    Map<String, String> locations = const {};
    Map<String, String> markets = const {};

    try {
      items = await referenceDataSource.fetchItemsByIds(itemIds);
    } catch (_) {}
    try {
      variants = await referenceDataSource.fetchVariantsByIds(variantIds);
    } catch (_) {}
    try {
      units = await referenceDataSource.fetchUnitsByIds(unitIds);
    } catch (_) {}
    try {
      locations = await referenceDataSource.fetchLocationsByIds(locationIds);
    } catch (_) {}
    try {
      final marketRows = await dataSource.listMarkets();
      markets = {
        for (final m in marketRows)
          if (_readString(m, ['id', 'market_id']) != null)
            _readString(m, ['id', 'market_id'])!:
                (_readString(m, ['market_name', 'name']) ?? ''),
      };
    } catch (_) {}

    return rows.map((row) {
      final avg = _readDouble(row, ['avg_price', 'average_price']) ?? 0;
      return DailyMarketPrice(
        id: _readString(row, ['id']) ?? '',
        locationId: _readString(row, ['location_id']),
        marketId: _readString(row, ['market_id']),
        itemId: _readString(row, ['item_id']),
        variantId: _readString(row, ['variant_id']),
        unitId: _readString(row, ['unit_id']),
        avgPrice: avg,
        minPrice: _readDouble(row, ['min_price']),
        maxPrice: _readDouble(row, ['max_price']),
        averagePrice: _readDouble(row, ['average_price']),
        recordedOn: _readDate(row, ['recorded_on']),
        priceType: _readString(row, ['price_type']),
        currency: _readString(row, ['currency']),
        qualityGrade: _readString(row, ['quality_grade']),
        observationCount: _readInt(row, ['observation_count']),
        itemName: _lookup(items, row, 'item_id'),
        variantName: _lookup(variants, row, 'variant_id'),
        unitName: _lookup(units, row, 'unit_id'),
        marketName: _lookup(markets, row, 'market_id'),
        locationName: _lookup(locations, row, 'location_id'),
      );
    }).toList();
  }

  @override
  Future<List<PriceFavourite>> fetchFavourites() async {
    final rows = await dataSource.fetchFavourites();
    return rows.map((row) {
      return PriceFavourite(
        id: _readString(row, ['id']) ?? '',
        marketId: _readString(row, ['market_id']),
        locationId: _readString(row, ['location_id']),
        itemId: _readString(row, ['item_id']),
        variantId: _readString(row, ['variant_id']),
      );
    }).toList();
  }

  @override
  Future<void> addFavourite({
    String? marketId,
    String? locationId,
    String? itemId,
    String? variantId,
  }) {
    return dataSource.addFavourite(
      marketId: marketId,
      locationId: locationId,
      itemId: itemId,
      variantId: variantId,
    );
  }

  @override
  Future<void> removeFavourite({required String favouriteId}) {
    return dataSource.removeFavourite(favouriteId: favouriteId);
  }

  // ── Helpers ──

  static Set<String> _collect(List<Map<String, dynamic>> rows, String key) {
    return rows
        .map((r) => r[key]?.toString())
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .toSet();
  }

  static String? _lookup(
    Map<String, String> map,
    Map<String, dynamic> row,
    String key,
  ) {
    final id = row[key]?.toString();
    if (id == null || id.isEmpty) return null;
    return map[id];
  }

  static String? _readString(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is String && value.isNotEmpty) return value;
      if (value != null) {
        final s = value.toString();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  static double? _readDouble(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  static int _readInt(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is num) return value.toInt();
    }
    return 0;
  }

  static DateTime? _readDate(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final s = value.toString();
      final parsed = DateTime.tryParse(s);
      if (parsed != null) return parsed;
    }
    return null;
  }
}
