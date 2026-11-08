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
import '../../application/providers/market_prices_provider.dart';
import '../../domain/entities/listing.dart';
import 'stock_selection_page.dart';
import 'market_prices_page.dart';

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

          // ── Market Prices entry (gated by marketplace.market_prices) ──
          _MarketPricesEntry(),

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

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _buildShelf(
                      context,
                      'Promoted',
                      filtered.where((l) => l.isPromoted).toList(),
                      promoted: true,
                    ),
                    for (final category in const [
                      'Livestock',
                      'Equipment',
                      'Crops',
                      'Inputs',
                      'Other',
                    ])
                      _buildShelf(
                        context,
                        category,
                        filtered
                            .where((listing) =>
                                _listingCategory(listing) == category)
                            .toList(),
                      ),
                  ],
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
      result = result
          .where((listing) => _listingCategory(listing).toUpperCase() == tab)
          .toList();
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

  /// Groups a listing into the Marketplace shelf/tab taxonomy.
  ///
  /// Priority:
  ///   1. The seller-chosen product taxonomy (`core.commodities.category`,
  ///      resolved variant → item → commodity). This is authoritative.
  ///   2. Keyword intent from item/variant/title/description for taxonomy
  ///      rows that are missing or generic ("other").
  ///   3. The unit of measure — only as a last resort, because it cannot
  ///      distinguish produce from inputs (milk and pesticide are both sold
  ///      per litre).
  String _listingCategory(Listing listing) {
    final canonical = _categoryFromCommodity(listing.commodityCategory);
    if (canonical != null) return canonical;

    final intent = _categoryFromKeywords(listing);
    if (intent != null) return intent;

    return _categoryFromUnit(listing.unitName);
  }

  static const List<String> _inputHints = [
    'fertilizer', 'fertiliser', 'dap', 'npk', 'urea', 'seed', 'seeds',
    'pesticide', 'herbicide', 'fungicide', 'insecticide', 'nematicide',
    'agrochemical', 'vaccine', 'veterinary', 'dewormer', 'acaricide',
    'feed', 'animal feed', 'poultry feed', 'livestock feed', 'fish feed',
    'feed supplement', 'chemical', 'drug',
  ];

  static const List<String> _equipmentHints = [
    'tractor', 'plough', 'plow', 'harrow', 'sprayer', 'pump', 'trailer',
    'mill', 'chaff cutter', 'chaffcutter', 'machine', 'machinery',
    'implement', 'tool', 'greenhouse', 'irrigation kit', 'wheelbarrow',
    'water tank', 'incubator',
  ];

  static const List<String> _livestockHints = [
    'cattle', 'cow', 'bull', 'heifer', 'calf', 'goat', 'sheep', 'ram', 'ewe',
    'pig', 'boar', 'sow', 'chicken', 'hen', 'cock', 'rooster', 'poultry',
    'duck', 'turkey', 'rabbit', 'donkey', 'camel', 'bee', 'bees', 'fish',
    'tilapia', 'catfish', 'salmon', 'trout', 'milk', 'cheese',
    'butter', 'ghee', 'yogurt', 'yoghurt', 'egg', 'honey', 'beef', 'mutton',
    'pork', 'meat', 'steak',
  ];

  static const List<String> _cropHints = [
    'maize', 'corn', 'bean', 'beans', 'rice', 'wheat', 'millet', 'sorghum',
    'barley', 'potato', 'tomato', 'onion', 'cabbage', 'kale', 'sukuma',
    'spinach', 'carrot', 'banana', 'mango', 'avocado', 'orange', 'pineapple',
    'coffee', 'tea', 'sugarcane', 'groundnut', 'simsim', 'soy', 'soya',
    'cowpea', 'cotton', 'tobacco', 'flower', 'seedling', 'fruit',
    'vegetable', 'cassava', 'yam', 'arrowroot', 'peas', 'lentil',
    'chickpea', 'ginger', 'garlic', 'chilli', 'pepper', 'cucumber',
    'watermelon', 'pumpkin', 'passion', 'strawberry', 'macadamia',
    'cashew', 'coconut', 'eggplant', 'grape', 'grapes',
  ];

  /// Word-aware keyword match (`seed` matches "seeds" but not "seedless").
  bool _matchesAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      final pattern = RegExp(
        '(^|[^a-z0-9])${RegExp.escape(needle)}(s|es)?([^a-z0-9]|\$)',
      );
      if (pattern.hasMatch(haystack)) return true;
    }
    return false;
  }

  /// Maps the canonical commodity category to a shelf, or null when the
  /// category is absent/generic so keyword intent can refine it.
  String? _categoryFromCommodity(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return null;
    switch (value) {
      case 'crop':
      case 'crops':
        return 'Crops';
      case 'livestock':
      case 'animal':
      case 'animals':
      case 'poultry':
      case 'dairy':
      case 'fish':
      case 'honey':
        return 'Livestock';
      case 'input':
      case 'inputs':
      case 'seed':
      case 'seeds':
        return 'Inputs';
      case 'equipment':
      case 'machinery':
        return 'Equipment';
      case 'other':
        return null;
    }
    if (_matchesAny(value, _inputHints) || value.contains('input')) {
      return 'Inputs';
    }
    if (_matchesAny(value, _equipmentHints) ||
        value.contains('equipment') ||
        value.contains('machin')) {
      return 'Equipment';
    }
    if (value.contains('livestock') ||
        value.contains('animal') ||
        value.contains('poultry') ||
        value.contains('dairy') ||
        value.contains('fish') ||
        value.contains('aquacultur') ||
        value.contains('apicultur') ||
        value.contains('honey')) {
      return 'Livestock';
    }
    if (value.contains('crop') ||
        value.contains('produce') ||
        value.contains('grain') ||
        value.contains('cereal') ||
        value.contains('horticult') ||
        value.contains('vegetable') ||
        value.contains('fruit') ||
        value.contains('legume') ||
        value.contains('tuber')) {
      return 'Crops';
    }
    return null;
  }

  /// Keyword intent from the seller-chosen item/variant plus the title.
  String? _categoryFromKeywords(Listing listing) {
    final haystack = [
      listing.itemName ?? '',
      listing.variantName ?? '',
      listing.title,
    ].join(' ').toLowerCase();

    if (_matchesAny(haystack, _inputHints)) return 'Inputs';
    if (_matchesAny(haystack, _equipmentHints)) return 'Equipment';
    if (_matchesAny(haystack, _livestockHints)) return 'Livestock';
    if (_matchesAny(haystack, _cropHints)) return 'Crops';

    final description = listing.description?.toLowerCase() ?? '';
    if (description.isNotEmpty) {
      if (_matchesAny(description, _inputHints)) return 'Inputs';
      if (_matchesAny(description, _equipmentHints)) return 'Equipment';
    }
    return null;
  }

  String _categoryFromUnit(String? rawUnit) {
    final unit = (rawUnit ?? '').toLowerCase().trim();
    if (unit == 'head' || unit == 'animal' || unit == 'livestock') {
      return 'Livestock';
    }
    if (unit == 'unit' || unit == 'hour' || unit == 'day') {
      return 'Equipment';
    }
    if (unit == 'kg' || unit == 'tonne' || unit == 'bag') return 'Crops';
    return 'Other';
  }

  Widget _buildShelf(
    BuildContext context,
    String title,
    List<Listing> listings, {
    bool promoted = false,
  }) {
    if (listings.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    // Card width mirrors the responsive shelf sizing below. The shelf height
    // is derived from the card's image area + compact details block so the
    // horizontal viewport does not force taller cards (which would leave an
    // empty band under the details).
    final bool compact = MediaQuery.sizeOf(context).width < 420;
    final double cardWidth = compact ? 142.0 : 176.0;
    final double imageHeight = (cardWidth / 1.35).clamp(108.0, 152.0);
    final double shelfHeight = imageHeight + 74;
    for (var start = 0; start < listings.length && start < 16; start += 8) {
      final end = start + 8 < listings.length ? start + 8 : listings.length;
      rows.add(
        SizedBox(
          height: shelfHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = start; i < end; i++) ...[
                  if (i > start) const SizedBox(width: 12),
                  SizedBox(
                    width: cardWidth,
                    child: ListingTile(listing: listings[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _activeTab = promoted ? 'ALL' : title.toUpperCase();
                }),
                child: const Text('See all ›'),
              ),
            ],
          ),
          ...rows,
        ],
      ),
    );
  }
}

/// ============================================================
/// MARKET PRICES ENTRY (gate + navigation)
/// ============================================================
///
/// A compact entry point into Market Prices, rendered only when the
/// `marketplace.market_prices` feature flag is enabled.
/// ============================================================
class _MarketPricesEntry extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureAsync = ref.watch(marketPricesFeatureEnabledProvider);

    return featureAsync.maybeWhen(
      data: (enabled) {
        if (!enabled) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MarketPricesPage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.insights_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Market Prices',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verified market intelligence by county, ward and market',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
