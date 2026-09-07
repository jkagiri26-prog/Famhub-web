/// ============================================================
/// BUSINESS HUB — LISTINGS TAB
/// ============================================================
///
/// Read/management visibility of the ACTIVE business's Marketplace
/// listings. Business Hub is the business-level surface; Marketplace
/// remains the specialized marketplace experience (creation, publishing,
/// editing and status changes stay in Marketplace).
///
/// Data source: canonical `marketplace.listings`, scoped to the active
/// business entity via the verified `entity_id` → core.entities seller
/// relationship. The read path is the existing Marketplace repository
/// (composition — no duplicate listing logic). Variant names come from
/// `core.item_variants`; availability from the linked
/// `commerce.stock_registry` row exposed by the Marketplace read.
///
/// Listing statuses are the real Marketplace enum values.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

import '../../application/providers/active_business_provider.dart';
import '../../application/providers/listings_provider.dart';
import '../../domain/entities/business_listing.dart';
import '../../domain/models/listings_summary.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

String _formatQty(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);

class BusinessHubListingsTab extends ConsumerWidget {
  const BusinessHubListingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    if (active == null) {
      return const EmptyStateWidget(
        icon: Icons.business_outlined,
        title: 'No active business',
        subtitle: 'Select a business to view its listings.',
      );
    }

    final listingsAsync = ref.watch(activeBusinessListingsProvider);

    return listingsAsync.when(
      loading: () => const LoadingStateWidget(
        message: 'Loading listings...',
      ),
      error: (e, _) => ErrorStateWidget(
        title: 'Failed to Load',
        message: 'Could not load listings for ${active.name}.',
        retryLabel: 'Retry',
        onRetry: () =>
            ref.invalidate(listingsByBusinessProvider(active.id)),
        detailedError: e.toString(),
      ),
      data: (listings) {
        if (listings.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.storefront_outlined,
            title: 'No listings yet',
            subtitle: 'Listings for this business appear here once items '
                'are published in Marketplace.',
          );
        }
        return _ListingsLoaded(listings: listings);
      },
    );
  }
}

/// ============================================================
/// LOADED STATE
/// ============================================================
class _ListingsLoaded extends ConsumerWidget {
  final List<BusinessListing> listings;

  const _ListingsLoaded({required this.listings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ListingsSummary.from(listings);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Compact summary chips ──
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                label: 'Listings',
                value: '${summary.totalCount}',
                color: theme.colorScheme.primary,
              ),
              if (summary.activeCount > 0)
                _SummaryChip(
                  label: 'Active',
                  value: '${summary.activeCount}',
                  color: Colors.green,
                ),
              if (summary.pausedCount > 0)
                _SummaryChip(
                  label: 'Paused',
                  value: '${summary.pausedCount}',
                  color: Colors.orange,
                ),
              if (summary.draftCount > 0)
                _SummaryChip(
                  label: 'Draft',
                  value: '${summary.draftCount}',
                  color: Colors.blueGrey,
                ),
              if (summary.soldOutCount > 0)
                _SummaryChip(
                  label: 'Sold out',
                  value: '${summary.soldOutCount}',
                  color: Colors.red,
                ),
              if (summary.inactiveCount > 0)
                _SummaryChip(
                  label: 'Inactive',
                  value: '${summary.inactiveCount}',
                  color: Colors.grey,
                ),
            ],
          ),
        ),

        // ── Compact listing list ──
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: listings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final listing = listings[index];
              return _ListingRow(
                listing: listing,
                onTap: () => _showDetail(context, listing),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, BusinessListing listing) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ListingDetailSheet(listing: listing),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// LISTING ROW
/// ============================================================
class _ListingRow extends StatelessWidget {
  final BusinessListing listing;
  final VoidCallback onTap;

  const _ListingRow({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            listing.displayItem,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (listing.isPromoted) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.bolt,
                              size: 14, color: Colors.amber.shade700),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listing.displayPrice,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusPill(status: listing.status),
                  const SizedBox(height: 3),
                  Text(
                    listing.isSoldOut
                        ? 'Sold out'
                        : listing.availableQuantity > 0
                            ? '${_formatQty(listing.availableQuantity)} '
                                '${listing.unitName ?? ''} avail'
                            : 'No stock',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ListingStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  (String, Color) _statusOf(ListingStatus status) {
    switch (status) {
      case ListingStatus.active:
        return ('Active', Colors.green.shade700);
      case ListingStatus.paused:
        return ('Paused', Colors.orange.shade800);
      case ListingStatus.draft:
        return ('Draft', Colors.blueGrey);
      case ListingStatus.soldOut:
        return ('Sold out', Colors.red.shade600);
      case ListingStatus.archived:
        return ('Archived', Colors.grey);
      case ListingStatus.inactive:
        return ('Inactive', Colors.grey.shade600);
    }
  }
}

/// ============================================================
/// LISTING DETAIL SHEET (read-only)
/// ============================================================
class _ListingDetailSheet extends ConsumerWidget {
  final BusinessListing listing;

  const _ListingDetailSheet({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    listing.displayItem,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusPill(status: listing.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Marketplace listing',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _detailRow(context, 'Item / Variant', listing.displayItem),
            _detailRow(context, 'Price', listing.displayPrice),
            if (listing.unitName != null && listing.unitName!.isNotEmpty)
              _detailRow(context, 'Unit', listing.unitName!),
            _detailRow(
                context,
                'Available',
                listing.isSoldOut
                    ? 'Sold out'
                    : '${_formatQty(listing.availableQuantity)} '
                        '${listing.unitName ?? ''}'.trim()),
            if (listing.reservedQuantity > 0)
              _detailRow(
                  context, 'Reserved', _formatQty(listing.reservedQuantity)),
            if (listing.locationName != null &&
                listing.locationName!.isNotEmpty)
              _detailRow(context, 'Location', listing.locationName!),
            _detailRow(context, 'Created', _formatDate(listing.createdAt)),
            if (listing.images.isNotEmpty)
              _detailRow(context, 'Media',
                  '${listing.images.length} image(s) — shown in Marketplace'),
            const Divider(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/marketplace');
                },
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Open Marketplace'),
              ),
            ),
            const SizedBox(height: 12),
            _detailRow(context, 'Listing ID', listing.id, mono: true),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Creating, publishing, editing and status changes remain '
                'Marketplace operations and are not performed here.',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
