import 'dart:typed_data';

import '../entities/listing.dart';
import '../entities/stock_item.dart';
import '../enums/listing_status.dart';
import '../models/listing_edit_changes.dart';
import '../models/listing_image_file.dart';
import '../models/listing_publication.dart';

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

  /// Publish a listing from managed stock and attach the selected photos.
  ///
  /// The listing is published with an empty `images` array; every photo is
  /// then uploaded through the hardened `upload_media` flow against the
  /// freshly-created listing id. Partial upload failures are reported in the
  /// returned report — the successful photos are never rolled back.
  Future<ListingPublicationReport> publishListingFromStockWithImages({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    List<SelectedListingImage> images = const [],
  });

  /// Upload a single prepared (WebP, ≤2 MB) image for an existing listing.
  Future<void> uploadListingImage({
    required Uint8List bytes,
    required String fileName,
    required String listingId,
  });

  /// Resolve temporary signed image URLs for a listing via
  /// `media_get_by_context`. Never persisted; display-only.
  Future<List<String>> fetchListingImageUrls(String listingId);

  /// Resolve a listing's photos (file id + temporary signed URL) via
  /// `media_get_by_context`.
  ///
  /// Unlike [fetchListingImageUrls], the file ids are preserved so the seller
  /// can delete individual photos through `delete_media`.
  Future<List<ListingImageFile>> fetchListingImageFiles(String listingId);

  /// Delete a listing image by `media.files.id` via `delete_media`.
  Future<void> deleteListingImage(String fileId);

  // ──────────────────────────────────────────────────────────
  // LISTING EDIT (PHASE — CANONICAL MUTATIONS)
  // ──────────────────────────────────────────────────────────
  //
  // Editing an existing listing goes exclusively through the two deployed
  // canonical RPCs. The client never writes `marketplace.listings` directly
  // and never submits entity/stock/variant/unit/location/images/status.
  //
  //   marketplace.update_listing(uuid, jsonb)   → metadata only
  //   marketplace.set_listing_status(uuid, text) → active | inactive
  //
  // Authorization (auth.uid() + can_manage membership) is performed entirely
  // by the backend; no user id, entity id or ownership claim is sent here.

  /// Update ONLY the editable listing metadata (title, description,
  /// price_per_unit, currency) via `marketplace.update_listing`.
  ///
  /// [changes] carries only changed editable fields. When [changes.isEmpty]
  /// the caller must not invoke this method — no mutation is possible.
  Future<Listing> updateListingDetails({
    required String listingId,
    required ListingEditChanges changes,
  });

  /// Set a listing status to `active` or `inactive` via
  /// `marketplace.set_listing_status`.
  ///
  /// Only [ListingStatus.active] and [ListingStatus.inactive] are accepted;
  /// any other value is rejected before reaching the backend.
  /// Activation is stock-validated by the backend (quantity > 0).
  Future<Listing> setListingStatus({
    required String listingId,
    required ListingStatus status,
  });
}
