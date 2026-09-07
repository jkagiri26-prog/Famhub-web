/// ============================================================
/// LISTINGS SUMMARY (DOMAIN MODEL)
/// ============================================================
///
/// Compact aggregate derived from the active business's listings.
/// Display-only counts computed client-side from canonical
/// `marketplace.listings` rows using the real Marketplace status enum.
/// Archived rows are not returned by the reused Marketplace read path.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';

import '../entities/business_listing.dart';

class ListingsSummary {
  final int totalCount;
  final int activeCount;
  final int pausedCount;
  final int draftCount;
  final int soldOutCount;
  final int inactiveCount;

  const ListingsSummary({
    required this.totalCount,
    required this.activeCount,
    required this.pausedCount,
    required this.draftCount,
    required this.soldOutCount,
    required this.inactiveCount,
  });

  factory ListingsSummary.from(List<BusinessListing> listings) {
    int countOf(ListingStatus status) =>
        listings.where((l) => l.status == status).length;
    return ListingsSummary(
      totalCount: listings.length,
      activeCount: countOf(ListingStatus.active),
      pausedCount: countOf(ListingStatus.paused),
      draftCount: countOf(ListingStatus.draft),
      soldOutCount: countOf(ListingStatus.soldOut),
      inactiveCount: countOf(ListingStatus.inactive),
    );
  }
}
