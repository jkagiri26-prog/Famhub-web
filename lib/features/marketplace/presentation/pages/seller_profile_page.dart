import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/cards/summary_panel_widget.dart';

import '../widgets/listing_tile.dart';
import '../../application/providers/marketplace_provider.dart';

class SellerProfilePage extends ConsumerWidget {
  final String sellerId;
  final String? sellerName;

  const SellerProfilePage({
    super.key,
    required this.sellerId,
    this.sellerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(sellerListingsProvider(sellerId));
    final statsAsync = ref.watch(sellerStatsProvider(sellerId));

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ModuleHeaderWidget(
            title: sellerName ?? 'Seller Profile',
            subtitle: 'Listings & performance',
          ),
          const SizedBox(height: 20),

          // Stats section
          statsAsync.when(
            loading: () => const LoadingStateWidget(),
            error: (e, _) => ErrorStateWidget(
              title: 'Could Not Load Stats',
              message: e.toString(),
              retryLabel: 'Retry',
              onRetry: () => ref.invalidate(sellerStatsProvider(sellerId)),
            ),
            data: (stats) => SummaryPanelWidget(
              metrics: [
                SummaryMetric(
                  label: 'Total',
                  value: '${stats['total_listings'] ?? 0}',
                  icon: Icons.inventory_2_outlined,
                  color: Colors.teal,
                ),
                SummaryMetric(
                  label: 'Active',
                  value: '${stats['active_listings'] ?? 0}',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                SummaryMetric(
                  label: 'Sold',
                  value: (stats['total_sold'] as num?)?.toStringAsFixed(0) ?? '0',
                  icon: Icons.sell_outlined,
                  color: Colors.blue,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Listings section
          Expanded(
            child: listingsAsync.when(
              loading: () => const LoadingStateWidget(
                message: 'Loading listings...',
                useSkeleton: true,
              ),
              error: (e, _) => ErrorStateWidget(
                title: 'Could Not Load Listings',
                message: e.toString(),
                retryLabel: 'Retry',
                onRetry: () => ref.invalidate(sellerListingsProvider(sellerId)),
              ),
              data: (listings) {
                if (listings.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.store_outlined,
                    title: 'No Listings',
                    subtitle: 'This seller has no listings yet.',
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: listings.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${listings.length} listing${listings.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    }
                    final listing = listings[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ListingTile(listing: listing),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

