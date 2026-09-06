import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/enums/listing_status.dart';
import '../../domain/models/listing_edit_changes.dart';
import '../../domain/models/listing_edit_images_state.dart';
import '../../domain/models/listing_image_file.dart';
import '../../domain/models/listing_publication.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../infrastructure/data_sources/marketplace_remote_data_source.dart';
import '../../infrastructure/repositories/marketplace_repository_impl.dart';

/// ============================================================
/// DATA SOURCE LAYER
/// ============================================================
final marketplaceRemoteDataSourceProvider =
    Provider<MarketplaceRemoteDataSource>((ref) {
  return MarketplaceRemoteDataSource();
});

/// ============================================================
/// REPOSITORY LAYER
/// ============================================================
final marketplaceRepositoryProvider =
    Provider<MarketplaceRepository>((ref) {
  final dataSource = ref.watch(marketplaceRemoteDataSourceProvider);
  return MarketplaceRepositoryImpl(dataSource);
});

/// ============================================================
/// MARKETPLACE CONTROLLER (ASYNC NOTIFIER)
/// ============================================================
final marketplaceProvider =
    AsyncNotifierProvider<MarketplaceController, List<Listing>>(
  MarketplaceController.new,
);

class MarketplaceController extends AsyncNotifier<List<Listing>> {
  MarketplaceRepository get _repo =>
      ref.read(marketplaceRepositoryProvider);

  @override
  Future<List<Listing>> build() async {
    return _safeFetch();
  }

  Future<List<Listing>> _safeFetch() async {
    try {
      return await _repo.fetchListings();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> load() async {
    state = const AsyncLoading();

    try {
      final data = await _repo.fetchListings();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> createListing(Map<String, dynamic> payload) async {
    await _repo.createListing(payload);
    ref.invalidateSelf();
  }

  Future<void> updateListing(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await _repo.updateListing(id, payload);

    ref.invalidateSelf();
    ref.invalidate(listingDetailsProvider(id));
  }

  Future<void> archiveListing(String id) async {
    await _repo.archiveListing(id);

    ref.invalidateSelf();
    ref.invalidate(listingDetailsProvider(id));
  }

  Future<void> publishListing(String id) async {
    await _repo.publishListing(id);

    ref.invalidateSelf();
    ref.invalidate(listingDetailsProvider(id));
  }

  /// Publish a listing from managed stock via the
  /// `marketplace.publish_listing_from_stock` RPC.
  ///
  /// Only the selected stock id, price, title, description and images are
  /// collected client-side; entity/variant/unit/location/quantity are
  /// resolved server-side under RLS. On success the marketplace cache is
  /// invalidated so the new listing appears immediately.
  Future<Listing> publishFromStock({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    List<String> images = const [],
  }) async {
    final listing = await _repo.publishListingFromStock(
      stockId: stockId,
      pricePerUnit: pricePerUnit,
      title: title,
      description: description,
      images: images,
    );

    // Refresh marketplace providers/cache so the freshly published listing
    // appears immediately in Marketplace.
    ref.invalidateSelf();
    ref.invalidate(eligibleStockProvider);

    return listing;
  }

  /// Publish a listing from managed stock, then attach the selected photos
  /// through the hardened media flow.
  ///
  /// The listing is published with an empty `images` array and every photo is
  /// uploaded against the returned listing id. Partial upload failures are
  /// reported — successful photos are preserved and marketplace/media state is
  /// refreshed from the backend.
  Future<ListingPublicationReport> publishListingWithImages({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    List<SelectedListingImage> images = const [],
  }) async {
    final report = await _repo.publishListingFromStockWithImages(
      stockId: stockId,
      pricePerUnit: pricePerUnit,
      title: title,
      description: description,
      images: images,
    );

    ref.invalidateSelf();
    ref.invalidate(eligibleStockProvider);
    if (report.listing.id.isNotEmpty) {
      ref.invalidate(listingDetailsProvider(report.listing.id));
      ref.invalidate(listingImageUrlsProvider(report.listing.id));
    }

    return report;
  }

    Future<void> updateInventory({
    required String listingId,
    double? availableQuantity,
    double? reservedQuantity,
  }) async {
    await _repo.updateInventory(
      listingId: listingId,
      availableQuantity: availableQuantity,
      reservedQuantity: reservedQuantity,
    );

    ref.invalidateSelf();
    ref.invalidate(listingDetailsProvider(listingId));
  }

  /// Update ONLY the editable listing metadata via the canonical
  /// `marketplace.update_listing` RPC.
  ///
  /// [changes] must already be non-empty; the repository refuses to mutate
  /// when nothing changed, so no RPC is ever attempted for a no-op edit.
  /// On success the narrowest affected state is refreshed: the listing feed,
  /// this listing's details and the seller's listing list.
  Future<Listing> updateListingDetails({
    required String listingId,
    required ListingEditChanges changes,
  }) async {
    final updated = await _repo.updateListingDetails(
      listingId: listingId,
      changes: changes,
    );

    ref.invalidateSelf();
    ref.invalidate(listingDetailsProvider(listingId));
    _invalidateSellerListings(updated.entityId);
    return updated;
  }

  /// Activate or deactivate a listing via the canonical
  /// `marketplace.set_listing_status` RPC (active | inactive only).
  ///
  /// Activation stock validation stays backend-authoritative.
  Future<Listing> setListingStatus({
    required String listingId,
    required ListingStatus status,
  }) async {
    final updated = await _repo.setListingStatus(
      listingId: listingId,
      status: status,
    );

    ref.invalidateSelf();
    ref.invalidate(listingDetailsProvider(listingId));
    _invalidateSellerListings(updated.entityId);
    return updated;
  }

  void _invalidateSellerListings(String entityId) {
    if (entityId.isNotEmpty) {
      ref.invalidate(sellerListingsProvider(entityId));
    }
  }

  /// Upload a prepared (WebP, ≤ 2 MB) photo for an existing listing via the
  /// hardened `upload_media` flow.
  ///
  /// The backend attaches the photo to the listing; the client never writes
  /// `listing.images`. On success the listing photo providers are refreshed.
  Future<void> uploadListingPhoto({
    required String listingId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _repo.uploadListingImage(
      bytes: bytes,
      fileName: fileName,
      listingId: listingId,
    );

    ref.invalidate(listingImageUrlsProvider(listingId));
    ref.invalidate(listingMediaFilesProvider(listingId));
  }

  /// Delete a listing photo by `media.files.id` via `delete_media`.
  Future<void> deleteListingPhoto({
    required String listingId,
    required String fileId,
  }) async {
    await _repo.deleteListingImage(fileId);

    ref.invalidate(listingImageUrlsProvider(listingId));
    ref.invalidate(listingMediaFilesProvider(listingId));
  }

  /// Commit a Listing Edit: metadata AND/OR staged image changes.
  ///
  /// Save is selective and never performs unnecessary RPCs:
  ///   - `update_listing` runs ONLY when [changes] is non-empty.
  ///   - staged additions are uploaded via `upload_media` ONLY when the
  ///     [images] draft has them.
  ///   - staged removals are deleted via `delete_media` ONLY when present.
  ///
  /// The media flow is authoritative for photos: the client never writes
  /// `marketplace.listings.images`. Partial image failures are reported in the
  /// returned [ListingEditSaveReport]; the caller must not pretend a partial
  /// save fully succeeded.
  ///
  /// Throws when the metadata update itself fails (nothing was uploaded for
  /// that save attempt). Image uploads/deletes that fail are reported, not
  /// thrown, so partially-applied changes can be surfaced and refreshed.
  Future<ListingEditSaveReport> saveListingEdit({
    required String listingId,
    required ListingEditChanges changes,
    ListingEditImagesState images = const ListingEditImagesState(),
  }) async {
    final metadataChanged = !changes.isEmpty;
    final imagesChanged = images.hasChanges;

    if (!metadataChanged && !imagesChanged) {
      throw ArgumentError('No editable fields or images changed.');
    }

    // STEP 1 — Metadata, only when changed. Throws so the caller can surface
    // the metadata failure without pretending the save succeeded.
    Listing? updated;
    if (metadataChanged) {
      updated = await _repo.updateListingDetails(
        listingId: listingId,
        changes: changes,
      );
    }

    // STEP 2 — Staged image changes, only when the draft has them. Failures
    // are collected per photo so successful uploads/deletes are preserved and
    // the partial result is reported truthfully.
    //
    // Removals are applied BEFORE additions so a replacement photo never makes
    // the backend transiently exceed the 3-photo ceiling during the swap.
    final failures = <String>[];
    var removedCount = 0;
    var uploadedCount = 0;

    if (imagesChanged) {
      for (final fileId in images.removedIds) {
        try {
          await _repo.deleteListingImage(fileId);
          removedCount++;
        } catch (e) {
          failures.add(_describeImageChangeFailure(e));
        }
      }

      for (final image in images.addedImages) {
        try {
          await _repo.uploadListingImage(
            bytes: image.bytes,
            fileName: image.fileName,
            listingId: listingId,
          );
          uploadedCount++;
        } catch (e) {
          failures.add(_describeImageChangeFailure(e));
        }
      }
    }

    // STEP 3 — Refresh narrow state so the updated listing/media are visible.
    if (metadataChanged) {
      ref.invalidateSelf();
      ref.invalidate(listingDetailsProvider(listingId));
    }
    if (imagesChanged) {
      ref.invalidate(listingImageUrlsProvider(listingId));
      ref.invalidate(listingMediaFilesProvider(listingId));
      ref.invalidate(listingDetailsProvider(listingId));
      ref.invalidateSelf();
    }
    if (updated != null && updated.entityId.isNotEmpty) {
      _invalidateSellerListings(updated.entityId);
    }

    return ListingEditSaveReport(
      updatedListing: updated,
      uploadedCount: uploadedCount,
      removedCount: removedCount,
      imageFailures: failures,
    );
  }

  String _describeImageChangeFailure(Object error) {
    final text = '$error'.toLowerCase();
    if (text.contains('session has expired') ||
        text.contains('sign in') ||
        text.contains('authentication') ||
        text.contains('authorization')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (text.contains('permission') ||
        text.contains('denied') ||
        text.contains('owner') ||
        text.contains('row-level')) {
      return "You don't have permission to change photos on this listing.";
    }
    if (text.contains('too large') ||
        text.contains('2 mb') ||
        text.contains('exceeds')) {
      return 'A photo was larger than the 2 MB limit.';
    }
    if (text.contains('socket') ||
        text.contains('connection') ||
        text.contains('network') ||
        text.contains('timeout') ||
        text.contains('failed to fetch')) {
      return "Couldn't reach the server. Check your connection and retry.";
    }
    final cleaned = text.startsWith('exception: ')
        ? text.substring('exception: '.length)
        : text;
    return cleaned.isEmpty ? 'Photo changes could not be applied.' : cleaned;
  }
}

/// ============================================================
/// DETAIL PROVIDERS
/// ============================================================
final listingDetailsProvider =
    FutureProvider.family<Listing?, String>((ref, id) async {
  final repo = ref.read(marketplaceRepositoryProvider);
  return repo.fetchListingById(id);
});

final sellerListingsProvider =
    FutureProvider.family<List<Listing>, String>((ref, sellerId) async {
  final repo = ref.read(marketplaceRepositoryProvider);
  return repo.fetchListings(sellerId: sellerId);
});

final sellerStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, sellerId) async {
    final repo = ref.read(marketplaceRepositoryProvider);
    return repo.getSellerStats(sellerId);
  },
);

/// ============================================================
/// MANAGED-STOCK PROVIDERS (PHASE 1)
/// ============================================================

/// Eligible managed stock owned by the authenticated user.
///
/// Reads `commerce.stock_registry` (RLS-scoped, available quantity > 0).
/// Powers the Marketplace → Add Listing stock-selection screen.
final eligibleStockProvider =
    FutureProvider<List<StockItem>>((ref) async {
  final repo = ref.read(marketplaceRepositoryProvider);
  return repo.fetchEligibleStock();
});

/// Read-only details for a single managed stock record.
///
/// Used by the publish form to display product/variant, available
/// quantity, unit and location without letting the client edit them.
final stockItemDetailsProvider =
    FutureProvider.family<StockItem?, String>((ref, stockId) async {
  final repo = ref.read(marketplaceRepositoryProvider);
  return repo.fetchStockById(stockId);
});

/// ============================================================
/// LISTING IMAGE URLS (SIGNED, TEMPORARY)
/// ============================================================

/// Resolves a listing's media to temporary signed image URLs via
/// `media_get_by_context`.
///
/// Listing.images holds `media.files` IDs — never URLs. This provider is the
/// presentation/runtime representation of those references. Signed URLs expire
/// and must never be persisted; invalidate the provider to refresh them.
final listingImageUrlsProvider =
    FutureProvider.family<List<String>, String>((ref, listingId) async {
  final repo = ref.read(marketplaceRepositoryProvider);
  return repo.fetchListingImageUrls(listingId);
});

/// Resolves a listing's photos (file id + temporary signed URL) via
/// `media_get_by_context`.
///
/// The file ids power per-photo deletion through `delete_media`; the signed
/// URLs are display-only and expire. Used by the listing image editor.
final listingMediaFilesProvider =
    FutureProvider.family<List<ListingImageFile>, String>(
        (ref, listingId) async {
  final repo = ref.read(marketplaceRepositoryProvider);
  return repo.fetchListingImageFiles(listingId);
});
