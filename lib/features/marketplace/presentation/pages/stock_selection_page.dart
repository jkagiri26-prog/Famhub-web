import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import '../../application/providers/marketplace_provider.dart';
import '../../domain/entities/stock_item.dart';
import 'publish_listing_page.dart';

/// ============================================================
/// STOCK SELECTION PAGE (MANAGED-STOCK, PHASE 1)
/// ============================================================
///
/// Shows the authenticated user's eligible managed stock
/// (`commerce.stock_registry`, RLS-scoped, available quantity > 0).
///
/// Marketplace → Add Listing lands here. Selecting a stock record opens
/// the shared [PublishListingPage] with the chosen stock_id preselected.
///
/// The same flow is reachable from Farm / Shop / Livestock stock screens,
/// optionally pre-filtered via [initialSearchQuery].
/// ============================================================
class StockSelectionPage extends ConsumerStatefulWidget {
  /// Optional pre-filled search text (e.g. launched from a specific
  /// farm/livestock screen with relevant context).
  final String? initialSearchQuery;

  /// Optional canonical variant to limit stock to the selected asset.
  final String? initialVariantId;

  const StockSelectionPage({
    super.key,
    this.initialSearchQuery,
    this.initialVariantId,
  });

  @override
  ConsumerState<StockSelectionPage> createState() =>
      _StockSelectionPageState();
}

class _StockSelectionPageState extends ConsumerState<StockSelectionPage> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialSearchQuery ?? '',
    );
    _query = widget.initialSearchQuery ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPublishForm(StockItem stock) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublishListingPage(stockId: stock.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(eligibleStockProvider);

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          const ModuleHeaderWidget(
            title: 'Add Listing',
            subtitle: 'Choose managed stock to sell',
          ),

          const SizedBox(height: 12),

          // ── Search ──
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search your stock...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
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
              setState(() => _query = value);
            },
          ),
          const SizedBox(height: 12),

          Expanded(
            child: stockAsync.when(
              loading: () => const LoadingStateWidget(
                message: 'Loading your stock...',
              ),
              error: (e, st) => ErrorStateWidget(
                title: 'Unable to Load Stock',
                message: 'We could not load your managed stock.',
                retryLabel: 'Retry',
                onRetry: () => ref.invalidate(eligibleStockProvider),
                detailedError: e.toString(),
              ),
              data: (stock) {
                final matchingStock = widget.initialVariantId == null
                    ? stock
                    : stock
                        .where((item) =>
                            item.variantId == widget.initialVariantId)
                        .toList();
                final hasVariantMatch = matchingStock.isNotEmpty;
                final filtered = _filterStock(
                  hasVariantMatch ? matchingStock : stock,
                  _query,
                );

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: _query.isNotEmpty
                        ? Icons.search_off
                        : Icons.inventory_2_outlined,
                    title: _query.isNotEmpty
                        ? 'No Matching Stock'
                        : 'No Managed Stock Yet',
                    subtitle: _query.isNotEmpty
                        ? 'Try a different search term or clear the search.'
                        : 'Add inventory to your entity before you can '
                            'publish listings.',
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!hasVariantMatch &&
                              widget.initialVariantId != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'No stock is linked to this asset variant. '
                                'Showing your eligible managed stock.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              '${filtered.length} stock item'
                              '${filtered.length == 1 ? '' : 's'} available',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    final item = filtered[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StockTile(
                        stock: item,
                        onTap: () => _openPublishForm(item),
                      ),
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

  List<StockItem> _filterStock(List<StockItem> stock, String query) {
    if (query.trim().isEmpty) return stock;
    final q = query.trim().toLowerCase();
    return stock
        .where((s) =>
            s.displayName.toLowerCase().contains(q) ||
            s.displayUnit.toLowerCase().contains(q) ||
            s.displayLocation.toLowerCase().contains(q))
        .toList();
  }
}

class _StockTile extends StatelessWidget {
  final StockItem stock;
  final VoidCallback onTap;

  const _StockTile({required this.stock, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 22,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${stock.availableQuantity.toStringAsFixed(0)} '
                          '${stock.displayUnit} available',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.place_outlined,
                    label: stock.displayLocation,
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.straighten_outlined,
                    label: stock.displayUnit,
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
