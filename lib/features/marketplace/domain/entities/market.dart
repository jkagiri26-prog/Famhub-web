/// ============================================================
/// MARKET (DOMAIN) — Market Prices geographic reference
/// ============================================================
///
/// Represents a market linked to the canonical location hierarchy:
///   County → Sub-county → Ward → Market
///
/// Populated from the `marketplace.list_markets` RPC (no client-side
/// location data is invented; the hierarchy comes from the backend).
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class Market {
  final String id;
  final String name;

  /// The market's own canonical `core.locations` id (market level).
  final String? locationId;

  // ── Canonical location hierarchy (from list_markets) ──
  final String? countyId;
  final String? countyName;
  final String? subCountyId;
  final String? subCountyName;
  final String? wardId;
  final String? wardName;

  const Market({
    required this.id,
    required this.name,
    this.locationId,
    this.countyId,
    this.countyName,
    this.subCountyId,
    this.subCountyName,
    this.wardId,
    this.wardName,
  });

  /// A stable rollup key for the county (id or name fallback).
  String get countyKey => (countyId != null && countyId!.isNotEmpty)
      ? countyId!
      : countyName ?? '';

  String get subCountyKey => (subCountyId != null && subCountyId!.isNotEmpty)
      ? subCountyId!
      : subCountyName ?? '';

  String get wardKey => (wardId != null && wardId!.isNotEmpty)
      ? wardId!
      : wardName ?? '';

  String get countyLabel => (countyName != null && countyName!.isNotEmpty)
      ? countyName!
      : (countyId ?? 'County');

  String get subCountyLabel =>
      (subCountyName != null && subCountyName!.isNotEmpty)
          ? subCountyName!
          : (subCountyId ?? 'Sub-county');

  String get wardLabel => (wardName != null && wardName!.isNotEmpty)
      ? wardName!
      : (wardId ?? 'Ward');
}
