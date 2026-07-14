/// ============================================================
/// MARKETPLACE — REPOSITORY IMPLEMENTATION
/// ============================================================
///
/// Implements the abstract MarketplaceRepository contract.
/// Bridge between domain layer and infrastructure data sources.
/// ============================================================
library;

import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
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
}

