import '../entities/listing.dart';
import '../enums/listing_status.dart';

/// Abstract repository contract for marketplace data operations.
///
/// Implementations handle the data source specifics.
abstract class MarketplaceRepository {
  Future<List<Listing>> fetchListings({
    String? category,
    String? searchQuery,
    String? sellerId,
    List<ListingStatus>? statusFilter,
  });

  Future<Listing?> fetchListingById(String id);

  Future<Listing> createListing(Map<String, dynamic> payload);

  Future<Listing> updateListing(String id, Map<String, dynamic> payload);

  Future<void> archiveListing(String id);

    Future<Listing> publishListing(String id);

  Future<void> updateInventory({
    required String listingId,
    double? availableQuantity,
    double? reservedQuantity,
  });

  Future<Map<String, dynamic>> getSellerStats(String sellerId);
}

