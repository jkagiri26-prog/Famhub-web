/// ============================================================
/// DAILY MARKET PRICE (DOMAIN)
/// ============================================================
///
/// Aggregated (verified) market-price information from
/// `marketplace.daily_market_prices`. This is the primary read model for
/// normal users — never draft/submitted/rejected observations.
///
/// The backend supplies observation-weighted geographic rollups; the
/// frontend must NOT recompute county/ward averages from market rows.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class DailyMarketPrice {
  final String id;

  final String? locationId;
  final String? marketId;
  final String? itemId;
  final String? variantId;
  final String? unitId;

  final double avgPrice;
  final double? minPrice;
  final double? maxPrice;
  final double? averagePrice;

  final DateTime? recordedOn;
  final String? priceType;
  final String? currency;
  final String? qualityGrade;
  final int observationCount;

  // ── Resolved display names (batched lookups, no cross-schema embeds) ──
  final String? itemName;
  final String? variantName;
  final String? unitName;
  final String? marketName;
  final String? locationName;

  const DailyMarketPrice({
    required this.id,
    this.locationId,
    this.marketId,
    this.itemId,
    this.variantId,
    this.unitId,
    required this.avgPrice,
    this.minPrice,
    this.maxPrice,
    this.averagePrice,
    this.recordedOn,
    this.priceType,
    this.currency,
    this.qualityGrade,
    this.observationCount = 0,
    this.itemName,
    this.variantName,
    this.unitName,
    this.marketName,
    this.locationName,
  });

  /// Display-friendly product label.
  String get productLabel {
    final parts = <String>[
      if (itemName != null && itemName!.isNotEmpty) itemName!,
      if (variantName != null && variantName!.isNotEmpty) variantName!,
    ];
    return parts.isNotEmpty ? parts.join(' · ') : 'Product';
  }

  String get displayCurrency => (currency != null && currency!.isNotEmpty)
      ? currency!
      : 'KES';

  String get displayUnit => (unitName != null && unitName!.isNotEmpty)
      ? unitName!
      : (unitId ?? '');

  DailyMarketPrice copyWith({
    String? id,
    String? itemName,
    String? variantName,
    String? unitName,
    String? marketName,
    String? locationName,
  }) {
    return DailyMarketPrice(
      id: id ?? this.id,
      locationId: locationId,
      marketId: marketId,
      itemId: itemId,
      variantId: variantId,
      unitId: unitId,
      avgPrice: avgPrice,
      minPrice: minPrice,
      maxPrice: maxPrice,
      averagePrice: averagePrice,
      recordedOn: recordedOn,
      priceType: priceType,
      currency: currency,
      qualityGrade: qualityGrade,
      observationCount: observationCount,
      itemName: itemName ?? this.itemName,
      variantName: variantName ?? this.variantName,
      unitName: unitName ?? this.unitName,
      marketName: marketName ?? this.marketName,
      locationName: locationName ?? this.locationName,
    );
  }
}
