import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';

import '../widgets/listing_card_widget.dart';
import '../../domain/entities/listing.dart';
import '../../application/providers/marketplace_provider.dart';

class ProductDetailsPage extends ConsumerWidget {
  final String? listingId;

  const ProductDetailsPage({
    super.key,
    this.listingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(marketplaceProvider);

    return listingsAsync.when(
      loading: () => const ResponsiveWrapperWidget(
        child: LoadingStateWidget(),
      ),
      error: (e, _) => ResponsiveWrapperWidget(
        child: EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Could Not Load Product',
          subtitle: e.toString(),
        ),
      ),
      data: (listings) {
        // Find the matching listing by ID, or use first as fallback
        final product = listingId != null
            ? listings.where((l) => l.id == listingId).firstOrNull
            : null;

        // If we have a listingId but no match, show empty state
        if (listingId != null && product == null) {
          return const ResponsiveWrapperWidget(
            child: EmptyStateWidget(
              icon: Icons.search_off,
              title: 'Product Not Found',
              subtitle: 'The requested listing could not be found.',
            ),
          );
        }

        // Use first listing if no ID provided, or show empty state
        final listing = product ?? (listings.isNotEmpty ? listings.first : null);

        if (listing == null) {
          return const ResponsiveWrapperWidget(
            child: EmptyStateWidget(
              icon: Icons.store,
              title: 'No Products Available',
              subtitle: 'Listings will appear here when available.',
            ),
          );
        }

        return _ProductDetailContent(listing: listing);
      },
    );
  }
}

class _ProductDetailContent extends StatelessWidget {
  final Listing listing;

  const _ProductDetailContent({required this.listing});

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapperWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const ModuleHeaderWidget(
            title: 'Product Details',
            subtitle: 'Seller details, AI insights, purchase flow',
          ),
          const SizedBox(height: 20),
          ListingCardWidget(
            title: listing.title,
            subtitle: listing.description ?? 'Market ready quality',
            price: 'KSh ${listing.price.toStringAsFixed(0)}',
            location: listing.location ?? listing.unit,
          ),
          const SizedBox(height: 20),
          // ── Seller Info Section ──
          if (listing.sellerName != null) ...[
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
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person, color: Colors.teal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listing.sellerName!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (listing.sellerRating != null)
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${listing.sellerRating}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Text(
                    listing.available ?? 'In Stock',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          // ── AI Assistant Section ──
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
        ],
      ),
    );
  }
}