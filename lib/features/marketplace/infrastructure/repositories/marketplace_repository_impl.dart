/// ============================================================
/// MARKETPLACE — REPOSITORY IMPLEMENTATION
/// ============================================================
///
/// Implements the abstract MarketplaceRepository contract.
/// Bridge between domain layer and infrastructure data sources.
/// ============================================================
library;

import 'dart:typed_data';

import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/entities/stock_item.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_edit_changes.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_image_file.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_publication.dart';
import 'package:famhub_app/features/marketplace/domain/repositories/marketplace_repository.dart';
import 'package:famhub_app/features/marketplace/infrastructure/data_sources/marketplace_remote_data_source.dart';

/// Local mapper implementation for marketplace listing JSON payloads.
class ListingMapper {
  static Listing fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      pricePerUnit: (json['price_per_unit'] ?? 0).toDouble(),
      currency: json['currency']?.toString() ?? 'KES',
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      entityId: json['entity_id']?.toString() ?? '',
      variantId: json['variant_id']?.toString() ?? '',
      stockId: json['stock_id']?.toString() ?? '',
      unitId: json['unit_id']?.toString(),
      locationId: json['location_id']?.toString(),
      contactVisibility: json['contact_visibility']?.toString() ?? 'locked',
      isPromoted: json['is_promoted'] == true,
      promotedUntil: json['promoted_until'] != null
          ? DateTime.tryParse(json['promoted_until'].toString())
          : null,
      status: ListingStatus.values.firstWhere(
        (s) => s.value == json['status']?.toString(),
        orElse: () => ListingStatus.active,
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      unitName: json['unit_name']?.toString(),
      locationName: json['location_name']?.toString(),
      sellerName: json['seller_name']?.toString(),
      sellerRating: (json['seller_rating'] as num?)?.toDouble(),
      availableQuantity: (json['available_quantity'] ?? 0).toDouble(),
      reservedQuantity: (json['reserved_quantity'] ?? 0).toDouble(),
    );
  }
}

/// Concrete implementation of [MarketplaceRepository].
///
/// Delegates data operations to [MarketplaceRemoteDataSource]
/// and maps raw data to domain entities via [ListingMapper].
class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final MarketplaceRemoteDataSource dataSource;

  MarketplaceRepositoryImpl(this.dataSource);

  /// Enrich a list of listings with seller profile data.
  ///
  /// Seller name and rating require a 2-hop join
  /// (entity_id → core.entities → commerce.business_profiles)
  /// which PostgREST cannot express natively.
  Future<List<Listing>> _enrichWithSellerProfiles(
      List<Map<String, dynamic>> rawListings) async {
    await _enrichReferencedData(rawListings);
    final enriched = <Listing>[];
    for (final raw in rawListings) {
      final entityId = raw['entity_id']?.toString();
      Listing listing;
      if (entityId != null && entityId.isNotEmpty) {
        try {
          final sellerProfile = await dataSource.fetchSellerProfile(entityId);
          if (sellerProfile != null) {
            raw['seller_name'] = sellerProfile['supplier_name']?.toString();
            raw['seller_rating'] = sellerProfile['rating'];
          }
        } catch (_) {
          // Silently continue without seller info
        }
      }
      listing = ListingMapper.fromJson(raw);
      enriched.add(listing);
    }
    return enriched;
  }

  /// Enrich a single listing with seller profile data.
  Future<Listing> _enrichSingleSellerProfile(
      Map<String, dynamic> raw) async {
    await _enrichReferencedData([raw]);
    final entityId = raw['entity_id']?.toString();
    if (entityId != null && entityId.isNotEmpty) {
      try {
        final sellerProfile = await dataSource.fetchSellerProfile(entityId);
        if (sellerProfile != null) {
          raw['seller_name'] = sellerProfile['supplier_name']?.toString();
          raw['seller_rating'] = sellerProfile['rating'];
        }
      } catch (_) {
        // Silently continue without seller info
      }
    }
    return ListingMapper.fromJson(raw);
  }

  /// Resolve all cross-schema referenced data (unit name, location name,
  /// stock quantities) in batched lookups and stamp the fields that
  /// [ListingMapper] reads (`unit_name`, `location_name`,
  /// `available_quantity`, `reserved_quantity`).
  ///
  /// This replaces every PostgREST FK embed on the listings query, which
  /// fails with "Could not find a relationship ... in the schema cache"
  /// when the PostgREST schema cache is stale for the cross-schema FKs.
  Future<void> _enrichReferencedData(
      List<Map<String, dynamic>> rawListings) async {
    final unitIds = <String>{};
    final locationIds = <String>{};
    final stockIds = <String>{};

    for (final raw in rawListings) {
      final unitId = raw['unit_id']?.toString();
      final locationId = raw['location_id']?.toString();
      final stockId = raw['stock_id']?.toString();
      if (unitId != null && unitId.isNotEmpty) unitIds.add(unitId);
      if (locationId != null && locationId.isNotEmpty) {
        locationIds.add(locationId);
      }
      if (stockId != null && stockId.isNotEmpty) stockIds.add(stockId);
    }

    if (unitIds.isEmpty && locationIds.isEmpty && stockIds.isEmpty) return;

    // Independent best-effort lookups — never fail the whole listing load.
    Map<String, String> units = const {};
    Map<String, String> locations = const {};
    Map<String, ({double quantity, double reservedQuantity})> stock = const {};
    try {
      units = await dataSource.fetchUnitsByIds(unitIds);
    } catch (_) {}
    try {
      locations = await dataSource.fetchLocationsByIds(locationIds);
    } catch (_) {}
    try {
      stock = await dataSource.fetchStockByIds(stockIds);
    } catch (_) {}

    for (final raw in rawListings) {
      final unitId = raw['unit_id']?.toString();
      if (unitId != null && units.containsKey(unitId)) {
        raw['unit_name'] = units[unitId];
      }
      final locationId = raw['location_id']?.toString();
      if (locationId != null && locations.containsKey(locationId)) {
        raw['location_name'] = locations[locationId];
      }
      final stockId = raw['stock_id']?.toString();
      if (stockId != null && stock.containsKey(stockId)) {
        raw['available_quantity'] = stock[stockId]!.quantity;
        raw['reserved_quantity'] = stock[stockId]!.reservedQuantity;
      }
    }
  }
  @override
  Future<List<Listing>> fetchListings({
    String? category,
    String? searchQuery,
    String? sellerId,
    List<ListingStatus>? statusFilter,
  }) async {
    final statusValue = statusFilter?.map((s) => s.value).join(',');
    final data = await dataSource.fetchListings(
      category: category,
      searchQuery: searchQuery,
      sellerId: sellerId,
      statusFilter: statusValue,
    );
    return _enrichWithSellerProfiles(data);
  }

  @override
  Future<Listing?> fetchListingById(String id) async {
    final data = await dataSource.fetchListingById(id);
    if (data == null) return null;
    return _enrichSingleSellerProfile(data);
  }

  @override
  Future<Listing> createListing(Map<String, dynamic> payload) async {
    final data = await dataSource.createListing(payload);
    return ListingMapper.fromJson(data);
  }

  @override
  Future<Listing> updateListing(
      String id, Map<String, dynamic> payload) async {
    final data = await dataSource.updateListing(id, payload);
    return ListingMapper.fromJson(data);
  }

  @override
  Future<Listing> updateListingDetails({
    required String listingId,
    required ListingEditChanges changes,
  }) async {
    if (changes.isEmpty) {
      throw ArgumentError('No editable listing fields changed.');
    }

    final data = await dataSource.updateListingDetails(
      listingId: listingId,
      changes: changes,
    );

    if (data != null) return ListingMapper.fromJson(data);

    // The RPC succeeded without returning a row; reload the listing so the
    // caller always gets canonical, freshly-mapped state.
    final refreshed = await dataSource.fetchListingById(listingId);
    if (refreshed != null) return _enrichSingleSellerProfile(refreshed);
    throw Exception('Listing was updated but could not be reloaded.');
  }

  @override
  Future<Listing> setListingStatus({
    required String listingId,
    required ListingStatus status,
  }) async {
    if (status != ListingStatus.active &&
        status != ListingStatus.inactive) {
      throw ArgumentError.value(
        status,
        'status',
        'Only active or inactive listing statuses are supported.',
      );
    }

    final data = await dataSource.setListingStatus(
      listingId: listingId,
      status: status.value,
    );

    if (data != null) return ListingMapper.fromJson(data);

    // The RPC succeeded without returning a row; reload the listing so the
    // caller always reflects the resulting backend state.
    final refreshed = await dataSource.fetchListingById(listingId);
    if (refreshed != null) return _enrichSingleSellerProfile(refreshed);
    throw Exception('Listing status was updated but could not be reloaded.');
  }

  @override
  Future<void> archiveListing(String id) async {
    await dataSource.archiveListing(id);
  }

  @override
  Future<Listing> publishListing(String id) async {
    final data = await dataSource.publishListing(id);
    return ListingMapper.fromJson(data);
  }

  @override
  Future<void> updateInventory({
    required String listingId,
    double? availableQuantity,
    double? reservedQuantity,
  }) async {
    await dataSource.updateInventory(
      listingId: listingId,
      availableQuantity: availableQuantity,
      reservedQuantity: reservedQuantity,
    );
  }

  @override
  Future<Map<String, dynamic>> getSellerStats(String sellerId) async {
    return dataSource.fetchSellerStats(sellerId);
  }

  // ──────────────────────────────────────────────────────────
  // MANAGED-STOCK PUBLISHING (PHASE 1)
  // ──────────────────────────────────────────────────────────

  /// Resolve display names for stock rows in batched lookups (no
  /// cross-schema PostgREST embeds) and build [StockItem] entities.
  Future<List<StockItem>> _buildStockItems(
      List<Map<String, dynamic>> rawRows) async {
    if (rawRows.isEmpty) return const [];

    final variantIds = <String>{};
    final itemIds = <String>{};
    final unitIds = <String>{};
    final locationIds = <String>{};

    for (final raw in rawRows) {
      final variantId = raw['variant_id']?.toString();
      final productId = raw['product_id']?.toString();
      final unitId = raw['unit_id']?.toString();
      final locationId = raw['location_id']?.toString();
      if (variantId != null && variantId.isNotEmpty) variantIds.add(variantId);
      if (productId != null && productId.isNotEmpty) itemIds.add(productId);
      if (unitId != null && unitId.isNotEmpty) unitIds.add(unitId);
      if (locationId != null && locationId.isNotEmpty) {
        locationIds.add(locationId);
      }
    }

    // Independent best-effort lookups — never fail the stock load.
    Map<String, String> variants = const {};
    Map<String, String> items = const {};
    Map<String, String> units = const {};
    Map<String, String> locations = const {};
    try {
      variants = await dataSource.fetchVariantsByIds(variantIds);
    } catch (_) {}
    try {
      items = await dataSource.fetchItemsByIds(itemIds);
    } catch (_) {}
    try {
      units = await dataSource.fetchUnitsByIds(unitIds);
    } catch (_) {}
    try {
      locations = await dataSource.fetchLocationsByIds(locationIds);
    } catch (_) {}

    final result = <StockItem>[];
    for (final raw in rawRows) {
      final variantId = raw['variant_id']?.toString();
      final productId = raw['product_id']?.toString();
      final unitId = raw['unit_id']?.toString();
      final locationId = raw['location_id']?.toString();

      // Product/variant display name: prefer the product (item) name and
      // fall back to the variant name when the product is not linked.
      final productName =
          (productId != null && items.containsKey(productId))
              ? items[productId]
              : (variantId != null && variants.containsKey(variantId))
                  ? variants[variantId]
                  : null;

      final stock = StockItem(
        id: raw['id']?.toString() ?? '',
        entityId: raw['entity_id']?.toString() ?? '',
        variantId: variantId,
        productName: productName,
        unitId: unitId,
        unitName: unitId != null && units.containsKey(unitId)
            ? units[unitId]
            : null,
        locationId: locationId,
        locationName: locationId != null && locations.containsKey(locationId)
            ? locations[locationId]
            : null,
        quantity: (raw['quantity'] as num?)?.toDouble() ?? 0,
        reservedQuantity: (raw['reserved_quantity'] as num?)?.toDouble() ?? 0,
      );

      // Only "eligible" managed stock can be listed.
      if (stock.isEligible) result.add(stock);
    }
    return result;
  }

  @override
  Future<List<StockItem>> fetchEligibleStock({String? searchQuery}) async {
    final rows = await dataSource.fetchManagedStock();
    var stock = await _buildStockItems(rows);

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      stock = stock
          .where((s) =>
              s.displayName.toLowerCase().contains(q) ||
              s.displayUnit.toLowerCase().contains(q) ||
              s.displayLocation.toLowerCase().contains(q))
          .toList();
    }
    return stock;
  }

  @override
  Future<StockItem?> fetchStockById(String stockId) async {
    final row = await dataSource.fetchManagedStockById(stockId);
    if (row == null) return null;
    final items = await _buildStockItems([row]);
    return items.isEmpty ? null : items.first;
  }

  @override
  Future<Listing> publishListingFromStock({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    required List<String> images,
  }) async {
    final data = await dataSource.publishListingFromStock(
      stockId: stockId,
      pricePerUnit: pricePerUnit,
      title: title,
      description: description,
      images: images,
    );
    if (data == null) {
      // The RPC succeeded but returned nothing; build a minimal listing
      // so callers can acknowledge the publication.
      return Listing(
        id: '',
        title: (title != null && title.trim().isNotEmpty)
            ? title.trim()
            : 'Published listing',
        description: description,
        pricePerUnit: pricePerUnit,
        currency: 'KES',
        images: List<String>.from(images),
        entityId: '',
        variantId: '',
        stockId: stockId,
        status: ListingStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return ListingMapper.fromJson(data);
  }

  @override
  Future<ListingPublicationReport> publishListingFromStockWithImages({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    List<SelectedListingImage> images = const [],
  }) async {
    // STEP 1 — Publish the listing with an empty images array. The listing is
    // created first so the hardened media flow can attach to its real id.
    final listing = await publishListingFromStock(
      stockId: stockId,
      pricePerUnit: pricePerUnit,
      title: title,
      description: description,
      images: const <String>[],
    );

    var listingId = listing.id;

    // STEP 2 — Resolve the newly-created listing id when the RPC returned no
    // row (best-effort recovery from the refreshed listings feed).
    if (listingId.isEmpty && images.isNotEmpty) {
      listingId = await _recoverListingIdByStock(stockId) ?? '';
    }

    if (listingId.isEmpty && images.isNotEmpty) {
      return ListingPublicationReport(
        listing: listing,
        uploadedCount: 0,
        failedCount: images.length,
        failures: const [
          'Listing was created but its identifier could not be confirmed, '
              'so no photos were attached.',
        ],
      );
    }

    // STEP 3 — Upload each selected photo against the created listing. The
    // backend attaches media to listing.images; the client never writes it.
    final failures = <String>[];
    var uploadedCount = 0;
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      try {
        await dataSource.uploadListingMedia(
          bytes: image.bytes,
          fileName: image.fileName,
          listingId: listingId,
        );
        uploadedCount++;
      } catch (e) {
        failures.add(
          'Photo ${i + 1} could not be uploaded: ${_friendlyMediaError(e)}',
        );
      }
    }

    final publishedListing = listingId.isNotEmpty && listing.id != listingId
        ? listing.copyWith(id: listingId)
        : listing;

    return ListingPublicationReport(
      listing: publishedListing,
      uploadedCount: uploadedCount,
      failedCount: images.length - uploadedCount,
      failures: failures,
    );
  }

  @override
  Future<void> uploadListingImage({
    required Uint8List bytes,
    required String fileName,
    required String listingId,
  }) async {
    await dataSource.uploadListingMedia(
      bytes: bytes,
      fileName: fileName,
      listingId: listingId,
    );
  }

  @override
  Future<List<String>> fetchListingImageUrls(String listingId) async {
    return dataSource.fetchListingMediaUrls(listingId);
  }

  @override
  Future<List<ListingImageFile>> fetchListingImageFiles(
      String listingId) async {
    final entries = await dataSource.fetchListingMediaEntries(listingId);
    return [
      for (final entry in entries)
        if (entry['id'] != null && entry['url'] != null)
          ListingImageFile(id: entry['id']!, url: entry['url']!),
    ];
  }

  @override
  Future<void> deleteListingImage(String fileId) async {
    await dataSource.deleteListingMedia(fileId);
  }

  /// Best-effort lookup of the listing id published for [stockId] using the
  /// canonical listings feed (newest first). Only used when the publish RPC
  /// returns no row.
  Future<String?> _recoverListingIdByStock(String stockId) async {
    try {
      final rows = await dataSource.fetchListings();
      for (final row in rows) {
        if (row['stock_id']?.toString() == stockId) {
          return row['id']?.toString();
        }
      }
    } catch (_) {
      // Recovery is best-effort; callers surface the report instead.
    }
    return null;
  }

  String _friendlyMediaError(Object e) {
    final text = e.toString();
    final lower = text.toLowerCase();
    if (lower.contains('session has expired') ||
        lower.contains('sign in') ||
        lower.contains('authentication')) {
      return 'your session has expired';
    }
    if (lower.contains('too large') ||
        lower.contains('2 mb') ||
        lower.contains('exceeds')) {
      return 'the file is too large';
    }
    if (lower.contains('format') ||
        lower.contains('unsupported') ||
        lower.contains('webp') ||
        lower.contains('read')) {
      return 'the file format is not supported';
    }
    if (lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('timeout')) {
      return 'check your connection and try again';
    }
    final cleaned = text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
    return cleaned.isEmpty ? 'please try again' : cleaned;
  }
}
