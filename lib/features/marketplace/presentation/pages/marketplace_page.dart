import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import '../widgets/marketplace_filter_tabs_widget.dart';
import '../widgets/listing_tile.dart';
import '../../application/providers/marketplace_provider.dart';
import '../../domain/entities/listing.dart';
import 'stock_selection_page.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  final _searchController = TextEditingController();
  String _activeTab = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ref.invalidate(marketplaceProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(marketplaceProvider);

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          ModuleHeaderWidget(
            title: 'Marketplace',
            subtitle: 'Buy & Sell — Inputs, Livestock, Produce',
            trailingIcon: Icons.add_circle_outline,
            onTrailingTap: () {
              // Phase 1: Add Listing → choose eligible managed stock →
              // publish from stock. Replaces the legacy raw-UUID form which
              // let the client submit entity/variant/unit/location directly.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StockSelectionPage(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search listings...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),

          const SizedBox(height: 12),

          MarketplaceFilterTabsWidget(
            activeTab: _activeTab,
            onChanged: (value) {
              setState(() => _activeTab = value);
            },
          ),
          const SizedBox(height: 12),

          Expanded(
            child: listingsAsync.when(
              loading: () => const LoadingStateWidget(
                message: 'Loading listings...',
              ),
              error: (e, _) => ErrorStateWidget(
                title: 'Failed to Load',
                message: 'Could not load marketplace listings.',
                retryLabel: 'Retry',
                onRetry: () => ref.invalidate(marketplaceProvider),
                detailedError: e.toString(),
              ),
              data: (listings) {
                final filtered = _filterListings(listings, _activeTab, _searchQuery);

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: _searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.store_outlined,
                    title: _searchQuery.isNotEmpty
                        ? 'No Results'
                        : 'No Listings Yet',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'Try a different search term or clear filters.'
                        : 'Create your first listing to start selling.',
                    actionLabel: _searchQuery.isNotEmpty ? 'Clear Search' : null,
                    onAction: _searchQuery.isNotEmpty
                        ? () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          }
                        : null,
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          '${filtered.length} listing${filtered.length == 1 ? '' : 's'} available',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    }

                    final listing = filtered[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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

  List<Listing> _filterListings(List<Listing> listings, String tab, String query) {
    var result = listings;

    if (tab != 'ALL') {
            result = result.where((l) {
        final category = (l.unitName ?? '').toLowerCase();
        switch (tab) {
          case 'LIVESTOCK':
            return category == 'head' || category == 'animal' || category == 'livestock';
          case 'CROPS':
            return category == 'kg' || category == 'tonne' || category == 'bag';
          case 'INPUTS':
            return category == 'litre' || category == 'pack' || category == 'piece';
          case 'MACHINERY':
            return category == 'unit' || category == 'hour' || category == 'day';
          case 'SERVICES':
            return category == 'service' || category == 'consultation';
          default:
            return true;
        }
      }).toList();
    }

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
            result = result.where((l) =>
        l.title.toLowerCase().contains(q) ||
        (l.description?.toLowerCase().contains(q) ?? false) ||
        (l.locationName?.toLowerCase().contains(q) ?? false) ||
        (l.sellerName?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    return result;
  }
}
