/// ============================================================
/// MARKETPLACE — REPOSITORY IMPLEMENTATION
/// ============================================================
///
/// Implements the abstract MarketplaceRepository contract.
/// Bridge between domain layer and infrastructure data sources.
/// ============================================================
library;

import '../../domain/entities/listing.dart';
import '../../domain/enums/listing_status.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../data_sources/marketplace_remote_data_source.dart';
import '../services/listing_mapper.dart';

/// Concrete implementation of [MarketplaceRepository].
///
/// Delegates data operations to [MarketplaceRemoteDataSource]
/// and maps raw data to domain entities via [ListingMapper].
class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final MarketplaceRemoteDataSource dataSource;

  MarketplaceRepositoryImpl(this.dataSource);

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
    return data.map((e) => ListingMapper.fromJson(e)).toList();
  }

  @override
  Future<Listing?> fetchListingById(String id) async {
    final data = await dataSource.fetchListingById(id);
    if (data == null) return null;
    return ListingMapper.fromJson(data);
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
    double? soldQuantity,
    double? reservedQuantity,
  }) async {
    await dataSource.updateInventory(
      listingId: listingId,
      availableQuantity: availableQuantity,
      soldQuantity: soldQuantity,
      reservedQuantity: reservedQuantity,
    );
  }

  @override
  Future<Map<String, dynamic>> getSellerStats(String sellerId) async {
    return dataSource.fetchSellerStats(sellerId);
  }
}
