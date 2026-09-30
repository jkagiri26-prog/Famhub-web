/// ============================================================
/// MARKET PRICES FILTER (DOMAIN)
/// ============================================================
///
/// Query parameters for market-price reads. All fields are optional;
/// the data source applies only the provided constraints.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class MarketPricesFilter {
  /// Geographic scoping (canonical location ids). `marketId` is the most
  /// specific; `locationId` supports ward/sub-county/county rollups.
  final String? marketId;
  final String? locationId;

  final String? itemId;
  final String? variantId;
  final String? unitId;

  /// One of 'farm_gate' | 'wholesale' | 'retail' (backend price_type).
  final String? priceType;

  final String? currency;

  /// Optional date (daily aggregation).
  final DateTime? recordedOn;

  const MarketPricesFilter({
    this.marketId,
    this.locationId,
    this.itemId,
    this.variantId,
    this.unitId,
    this.priceType,
    this.currency,
    this.recordedOn,
  });

  bool get hasGeographicScope =>
      (marketId != null && marketId!.isNotEmpty) ||
      (locationId != null && locationId!.isNotEmpty);

  MarketPricesFilter copyWith({
    String? marketId,
    String? locationId,
    String? itemId,
    String? variantId,
    String? unitId,
    String? priceType,
    String? currency,
    DateTime? recordedOn,
    bool clearMarketId = false,
    bool clearLocationId = false,
    bool clearItemId = false,
    bool clearVariantId = false,
    bool clearUnitId = false,
    bool clearPriceType = false,
    bool clearCurrency = false,
    bool clearRecordedOn = false,
  }) {
    return MarketPricesFilter(
      marketId: clearMarketId ? null : (marketId ?? this.marketId),
      locationId: clearLocationId ? null : (locationId ?? this.locationId),
      itemId: clearItemId ? null : (itemId ?? this.itemId),
      variantId: clearVariantId ? null : (variantId ?? this.variantId),
      unitId: clearUnitId ? null : (unitId ?? this.unitId),
      priceType: clearPriceType ? null : (priceType ?? this.priceType),
      currency: clearCurrency ? null : (currency ?? this.currency),
      recordedOn: clearRecordedOn ? null : (recordedOn ?? this.recordedOn),
    );
  }
}
