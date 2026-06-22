import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'listing_card_widget.dart';
import 'listing_status_badge.dart';
import '../../domain/entities/listing.dart';
import '../pages/product_details_page.dart';

/// Reusable listing tile with navigation, status badge, and card display.
/// Used in marketplace_page, seller_profile_page, and anywhere listings render.
class ListingTile extends ConsumerWidget {
  final Listing listing;

  const ListingTile({super.key, required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBadge = listing.status != ListingStatus.active;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(listingId: listing.id),
          ),
        );
      },
      child: ListingCardWidget(
        title: listing.title,
        subtitle: listing.description ?? 'No description available',
        price: 'KSh ${listing.price.toStringAsFixed(0)}/${listing.unit}',
        location: listing.location ?? 'Unknown',
        trailing: showBadge ? ListingStatusBadge(status: listing.status) : null,
      ),
    );
  }
}
