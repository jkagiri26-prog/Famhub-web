import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/cards/info_tile_widget.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/features/marketplace/presentation/widgets/listing_card_widget.dart';
import 'package:famhub_app/features/marketplace/presentation/widgets/listing_status_badge.dart';
import 'package:famhub_app/features/marketplace/presentation/widgets/marketplace_health_widget.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/listing_edit_page.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/seller_profile_page.dart';

class ProductDetailsPage extends ConsumerWidget {
  final String? listingId;

  const ProductDetailsPage({
    super.key,
    this.listingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If no listingId, show empty state
    if (listingId == null) {
      return const ResponsiveWrapper(
        child: EmptyStateWidget(
          icon: Icons.store,
          title: 'No Product Selected',
          subtitle: 'Select a listing to view details.',
        ),
      );
    }

    // Use listingDetailsProvider for targeted single-listing load
    final listingAsync = ref.watch(listingDetailsProvider(listingId!));

    return listingAsync.when(
      loading: () => const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Loading product...'),
      ),
      error: (e, _) => ResponsiveWrapper(
        child: ErrorStateWidget(
          title: 'Could Not Load Product',
          message: 'Failed to load listing details.',
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(listingDetailsProvider(listingId!)),
          detailedError: e.toString(),
        ),
      ),
      data: (listing) {
        if (listing == null) {
          return const ResponsiveWrapper(
            child: EmptyStateWidget(
              icon: Icons.search_off,
              title: 'Product Not Found',
              subtitle: 'The requested listing could not be found.',
            ),
          );
        }

        return _ProductDetailContent(listing: listing);
      },
    );
  }
}

class _ProductDetailContent extends ConsumerWidget {
  final Listing listing;

  const _ProductDetailContent({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = switch (listing.status) {
      ListingStatus.active => Colors.green,
      ListingStatus.draft => Colors.grey,
      ListingStatus.paused => Colors.orange,
      ListingStatus.soldOut => Colors.red,
      ListingStatus.archived => Colors.grey,
      ListingStatus.inactive => Colors.grey,
    };

    final availabilityText = switch (listing.status) {
      ListingStatus.active => '${listing.availableQuantity.toStringAsFixed(0)} ${listing.unitName ?? ''} available',
      ListingStatus.soldOut => 'Sold Out',
      ListingStatus.draft => 'Draft',
      ListingStatus.paused => 'Paused',
      ListingStatus.archived => 'Archived',
      ListingStatus.inactive => 'Inactive',
    };

    final imageUrls =
        ref.watch(listingImageUrlsProvider(listing.id)).value ?? const [];

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const ModuleHeaderWidget(
            title: 'Product Details',
            subtitle: 'Seller details, pricing & availability',
          ),
          const SizedBox(height: 20),

          // Seller action: edit listing metadata & availability. Backend
          // authorization is authoritative — no ownership claim is sent.
          if (ref.watch(isAuthenticatedProvider) &&
              listing.status != ListingStatus.archived) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ListingEditPage(listingId: listing.id),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Listing'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main listing card
          ListingCardWidget(
            title: listing.title,
            subtitle: listing.description ?? 'Market ready quality',
            price: listing.displayPrice,
            location: listing.locationName ?? listing.locationId ?? 'Unknown',
            imageUrl: imageUrls.isEmpty ? null : imageUrls.first,
          ),

          if (imageUrls.length > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageUrls.length - 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final url = imageUrls[index + 1];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      width: 88,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Status & Availability Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        availabilityText,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                                            Text(
                        'Reserved: ${listing.reservedQuantity.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                                // ListingStatusBadge(status: listing.status),
              ],
            ),
          ),

          const SizedBox(height: 16),

                    // Seller Info Section
          if (listing.sellerName != null) ...[
            InfoTileWidget(
              label: listing.sellerName!,
              value: listing.sellerRating != null
                  ? 'Rating: ${listing.sellerRating}'
                  : 'Seller',
              icon: Icons.person,
                            onTap: listing.entityId.isNotEmpty
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SellerProfilePage(
                            sellerId: listing.entityId,
                            sellerName: listing.sellerName,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 16),
          ],

                    // AI Assistant Section (future)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI Assistant + Seller Unlock System',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.blue.shade400),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const MarketplaceHealthWidget(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
