import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/listing_edit_page.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/seller_profile_page.dart';
import 'package:famhub_app/features/marketplace/presentation/widgets/buy_order_section.dart';
import 'package:famhub_app/features/marketplace/presentation/widgets/contact_unlock_section.dart';
import 'package:famhub_app/features/marketplace/presentation/widgets/listing_card_widget.dart';
import 'package:famhub_app/features/reputation/presentation/widgets/reputation_subject_ratings.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

class ProductDetailsPage extends ConsumerWidget {
  final String? listingId;

  const ProductDetailsPage({super.key, this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (listingId == null) {
      return const ResponsiveWrapper(
        child: EmptyStateWidget(
          icon: Icons.store,
          title: 'No Product Selected',
          subtitle: 'Select a listing to view details.',
        ),
      );
    }

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
    final imageUrls =
        ref.watch(listingImageUrlsProvider(listing.id)).value ?? const [];
    final activeEntityId = ref.watch(
      contextProvider.select((context) => context.entityId),
    );
    final canEdit =
        ref.watch(isAuthenticatedProvider) &&
        activeEntityId == listing.entityId &&
        listing.status != ListingStatus.archived;

    return ResponsiveWrapper(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const ModuleHeaderWidget(
              title: 'Listing Details',
              subtitle: 'Product information, availability & seller',
            ),
            const SizedBox(height: 20),

            if (canEdit) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ListingEditPage(listingId: listing.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Listing'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            ListingCardWidget(
              title: listing.title,
              subtitle: _productLabel(listing),
              price: listing.displayPrice,
              location: listing.locationName ?? 'Location unavailable',
              sellerName: listing.sellerName,
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
            _OverviewCard(listing: listing),
            const SizedBox(height: 16),
            _DescriptionCard(listing: listing),
            const SizedBox(height: 16),
            _SpecificationsCard(listing: listing),
            const SizedBox(height: 16),
            _AvailabilityCard(listing: listing),
            const SizedBox(height: 16),
            BuyOrderSection(listing: listing),
            const SizedBox(height: 16),
            _SellerCard(listing: listing),
            const SizedBox(height: 16),
            _ReviewsCard(listing: listing),
            const SizedBox(height: 16),

            if (ref.watch(isAuthenticatedProvider) &&
                listing.contactVisibility == 'locked') ...[
              ContactUnlockSection(listing: listing),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

String _productLabel(Listing listing) {
  final item = listing.itemName?.trim() ?? '';
  final variant = listing.variantName?.trim() ?? '';
  if (item.isEmpty && variant.isEmpty) return '';
  if (variant.isEmpty || variant == item) return item;
  return '$item · $variant';
}

String _categoryLabel(Listing listing) {
  final candidates = [
    listing.itemCategory,
    listing.commodityCategory,
    listing.itemDomain,
  ];
  for (final candidate in candidates) {
    if (candidate != null && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return 'Marketplace';
}

String _statusLabel(ListingStatus status) {
  return switch (status) {
    ListingStatus.active => 'Active',
    ListingStatus.draft => 'Draft',
    ListingStatus.paused => 'Paused',
    ListingStatus.soldOut => 'Sold out',
    ListingStatus.archived => 'Archived',
    ListingStatus.inactive => 'Inactive',
  };
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatQuantity(double value, String? unit) {
  final formatted = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  final suffix = unit == null || unit.trim().isEmpty ? '' : ' ${unit.trim()}';
  return '$formatted$suffix';
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final Listing listing;

  const _OverviewCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Overview',
      child: Column(
        children: [
          _InfoRow(label: 'Category', value: _categoryLabel(listing)),
          if (_productLabel(listing).isNotEmpty)
            _InfoRow(label: 'Product', value: _productLabel(listing)),
          _InfoRow(
            label: 'Location',
            value: listing.locationName ?? 'Location unavailable',
          ),
          _InfoRow(label: 'Status', value: _statusLabel(listing.status)),
          _InfoRow(label: 'Posted', value: _formatDate(listing.createdAt)),
          _InfoRow(label: 'Updated', value: _formatDate(listing.updatedAt)),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final Listing listing;

  const _DescriptionCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final description = listing.description?.trim() ?? '';
    return _SectionCard(
      title: 'Description',
      child: description.isEmpty
          ? Text(
              'No description provided.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          : Text(
              description,
              style: const TextStyle(fontSize: 14, height: 1.55),
            ),
    );
  }
}

class _SpecificationsCard extends ConsumerWidget {
  final Listing listing;

  const _SpecificationsCard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specsAsync = ref.watch(
      listingSpecificationsProvider(listing.variantId),
    );

    return _SectionCard(
      title: 'Product information',
      child: specsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, __) => Text(
          'Structured product information is unavailable.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        data: (specs) {
          if (specs.isEmpty) {
            return Text(
              'No structured specifications were provided. See the seller '
              'description above.',
              style: TextStyle(color: Colors.grey.shade600),
            );
          }
          return Column(
            children: [
              for (final spec in specs)
                _InfoRow(label: spec.name, value: spec.value),
            ],
          );
        },
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final Listing listing;

  const _AvailabilityCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final standalone = listing.isStandalone;
    final quantity = standalone
        ? (listing.quantityOffered ?? listing.availableQuantity)
        : listing.availableQuantity;
    final label = standalone ? 'Listing availability' : 'Available stock';
    final note = standalone
        ? 'Seller-declared quantity offered through this listing.'
        : 'Availability derived from managed inventory.';

    return _SectionCard(
      title: 'Availability',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            label: label,
            value: _formatQuantity(quantity, listing.unitName),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  final Listing listing;

  const _SellerCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final sellerName = listing.sellerName?.trim();
    if (sellerName == null || sellerName.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      title: 'Seller',
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(
              Icons.storefront_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sellerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: listing.entityId.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SellerProfilePage(
                          sellerId: listing.entityId,
                          sellerName: sellerName,
                        ),
                      ),
                    );
                  },
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  final Listing listing;

  const _ReviewsCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Reviews & ratings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReputationSubjectRatings(
            kind: ReputationSubjectKind.product,
            canonicalId: listing.variantId,
            title: 'Product ratings',
          ),
          const Divider(height: 28),
          ReputationSubjectRatings(
            kind: ReputationSubjectKind.seller,
            canonicalId: listing.entityId,
            title: 'Seller ratings',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
