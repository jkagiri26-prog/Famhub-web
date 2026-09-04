import '../entities/listing.dart';
import '../entities/stock_item.dart';
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

  // ──────────────────────────────────────────────────────────
  // MANAGED-STOCK PUBLISHING (PHASE 1)
  // ──────────────────────────────────────────────────────────
  //
  // Reads come from `commerce.stock_registry` (the existing inventory
  // system) scoped by RLS. Publishing is delegated entirely to the
  // `marketplace.publish_listing_from_stock` RPC — the client never
  // inserts into `marketplace.listings` and never submits entity_id,
  // variant_id, unit_id, location_id or listing quantity.

  /// Eligible managed stock owned by the authenticated user
  /// (available quantity > 0, scoped by RLS).
  Future<List<StockItem>> fetchEligibleStock({String? searchQuery});

  /// Fetch a single managed stock record by id (scoped by RLS).
  Future<StockItem?> fetchStockById(String stockId);

  /// Publish a listing from an existing managed stock record via the
  /// `marketplace.publish_listing_from_stock` RPC.
  Future<Listing> publishListingFromStock({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    required List<String> images,
  });
}
