import '../../domain/entities/listing.dart';
import '../../infrastructure/services/listing_mapper.dart';
import '../../infrastructure/services/marketplace_service.dart';

class MarketplaceRepository {
  final MarketplaceService service;

  MarketplaceRepository(this.service);

  Future<List<Listing>> fetchListings({
    String? category,
    String? searchQuery,
    String? sellerId,
    List<ListingStatus>? statusFilter,
  }) async {
    final data = await service.getListings(
      category: category,
      searchQuery: searchQuery,
      sellerId: sellerId,
      statusFilter: statusFilter,
    );
    return data.map((e) => ListingMapper.fromJson(e)).toList();
  }

  Future<Listing?> fetchListingById(String id) async {
    final data = await service.getListingById(id);
    if (data == null) return null;
    return ListingMapper.fromJson(data);
  }

  Future<Listing> createListing(Map<String, dynamic> payload) async {
    final data = await service.createListing(payload);
    return ListingMapper.fromJson(data);
  }

  Future<Listing> updateListing(String id, Map<String, dynamic> payload) async {
    final data = await service.updateListing(id, payload);
    return ListingMapper.fromJson(data);
  }

  Future<void> archiveListing(String id) async {
    await service.archiveListing(id);
  }

  Future<Listing> publishListing(String id) async {
    final data = await service.publishListing(id);
    return ListingMapper.fromJson(data);
  }

  Future<void> updateInventory({
    required String listingId,
    double? availableQuantity,
    double? soldQuantity,
    double? reservedQuantity,
  }) async {
    await service.updateInventory(
      listingId: listingId,
      availableQuantity: availableQuantity,
      soldQuantity: soldQuantity,
      reservedQuantity: reservedQuantity,
    );
  }

  Future<Map<String, dynamic>> getSellerStats(String sellerId) async {
    return service.getSellerStats(sellerId);
  }
}
