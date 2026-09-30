import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import '../../application/providers/market_prices_provider.dart';
import '../../domain/entities/daily_market_price.dart';
import '../../domain/entities/market.dart';

/// ============================================================
/// MARKET PRICES PAGE
/// ============================================================
///
/// Displays VERIFIED market-price intelligence sourced from
/// `marketplace.daily_market_prices` (aggregated) scoped by the canonical
/// location hierarchy (County → Sub-county → Ward → Market) from the
/// `marketplace.list_markets` RPC.
///
/// The geographic rollups are observation-weighted backend aggregates —
/// the frontend never averages market rows into county averages.
/// ============================================================
class MarketPricesPage extends ConsumerStatefulWidget {
  const MarketPricesPage({super.key});

  @override
  ConsumerState<MarketPricesPage> createState() => _MarketPricesPageState();
}

class _MarketPricesPageState extends ConsumerState<MarketPricesPage> {
  // Client-side refinement filters (geo scope comes from the provider).
  String? _priceType;
  String? _itemId;
  String? _variantId;
  String? _unitId;
  String? _currency;

  static const _priceTypes = <(String, String)>[
    ('', 'All types'),
    ('farm_gate', 'Farm Gate / Producer'),
    ('wholesale', 'Wholesale'),
    ('retail', 'Retail'),
  ];

  @override
  Widget build(BuildContext context) {
    final featureAsync = ref.watch(marketPricesFeatureEnabledProvider);

    return featureAsync.when(
      loading: () => const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Checking availability...'),
      ),
      error: (_, __) => const ResponsiveWrapper(
        child: EmptyStateWidget(
          icon: Icons.block,
          title: 'Market Prices unavailable',
          subtitle: 'This feature could not be loaded right now.',
        ),
      ),
      data: (enabled) {
        if (!enabled) {
          return const ResponsiveWrapper(
            child: EmptyStateWidget(
              icon: Icons.lock_outline,
              title: 'Market Prices unavailable',
              subtitle: 'This feature is not enabled for your account.',
            ),
          );
        }
        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final marketsAsync = ref.watch(marketsProvider);
    final filter = ref.watch(marketPricesFilterProvider);
    final pricesAsync = ref.watch(dailyMarketPricesProvider);

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const ModuleHeaderWidget(
            title: 'Market Prices',
            subtitle: 'Verified market intelligence — County › Ward › Market',
          ),
          const SizedBox(height: 16),

          // ── Geographic navigation ──
          marketsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => ErrorStateWidget(
              title: 'Could not load markets',
              message: e.toString(),
              retryLabel: 'Retry',
              onRetry: () => ref.invalidate(marketsProvider),
            ),
            data: (markets) => _buildGeoSelector(context, markets, filter),
          ),
          const SizedBox(height: 12),

          // ── Refinement filters ──
          _buildFilters(pricesAsync.value ?? const []),
          const SizedBox(height: 12),

          // ── Prices ──
          Expanded(
            child: pricesAsync.when(
              loading: () => const LoadingStateWidget(
                message: 'Loading market prices...',
              ),
              error: (e, _) => ErrorStateWidget(
                title: 'Could not load prices',
                message: e.toString(),
                retryLabel: 'Retry',
                onRetry: () => ref.invalidate(dailyMarketPricesProvider),
              ),
              data: (prices) => _buildPriceList(context, prices, filter),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // GEOGRAPHIC NAVIGATION
  // ───────────────────────────────────────────────────────────
  Widget _buildGeoSelector(
    BuildContext context,
    List<Market> markets,
    MarketPricesFilterState filter,
  ) {
    if (markets.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.location_off_outlined,
        title: 'No markets available',
        subtitle: 'Market locations have not been configured yet.',
      );
    }

    final counties = _distinct(
      markets.map((m) => (m.countyKey, m.countyLabel)),
    );
    final subCounties = filter.countyId == null
        ? const <(String, String)>[]
        : _distinct(markets
            .where((m) => m.countyKey == filter.countyId)
            .map((m) => (m.subCountyKey, m.subCountyLabel)));
    final wards = filter.subCountyId == null
        ? const <(String, String)>[]
        : _distinct(markets
            .where((m) => m.subCountyKey == filter.subCountyId)
            .map((m) => (m.wardKey, m.wardLabel)));
    final marketOptions = filter.wardId == null
        ? const <(String, String)>[]
        : _distinct(markets
            .where((m) => m.wardKey == filter.wardId)
            .map((m) => (m.id, m.name)));

    final notifier = ref.read(marketPricesFilterProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _geoDropdown(
          context,
          label: 'County',
          hint: 'Select county',
          value: filter.countyId,
          options: counties,
          onChanged: (v) => notifier.selectCounty(v),
        ),
        if (filter.countyId != null) ...[
          const SizedBox(height: 8),
          _geoDropdown(
            context,
            label: 'Sub-county',
            hint: 'Select sub-county',
            value: filter.subCountyId,
            options: subCounties,
            onChanged: (v) => notifier.selectSubCounty(v),
          ),
        ],
        if (filter.subCountyId != null) ...[
          const SizedBox(height: 8),
          _geoDropdown(
            context,
            label: 'Ward',
            hint: 'Select ward',
            value: filter.wardId,
            options: wards,
            onChanged: (v) => notifier.selectWard(v),
          ),
        ],
        if (filter.wardId != null) ...[
          const SizedBox(height: 8),
          _geoDropdown(
            context,
            label: 'Market',
            hint: 'Select market',
            value: filter.marketId,
            options: marketOptions,
            onChanged: (v) => notifier.selectMarket(v),
          ),
        ],
      ],
    );
  }

  Widget _geoDropdown(
    BuildContext context, {
    required String label,
    required String hint,
    required String? value,
    required List<(String, String)> options,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: Text(hint),
      items: options
          .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
          .toList(),
      onChanged: (v) => onChanged(v),
    );
  }

  // ───────────────────────────────────────────────────────────
  // REFINEMENT FILTERS (client-side, over the geo-scoped result)
  // ───────────────────────────────────────────────────────────
  Widget _buildFilters(List<DailyMarketPrice> prices) {
    final items = _distinct(
      prices.map((p) => (p.itemId ?? '', p.itemName ?? 'Product')),
    );
    final variants = _distinct(
      prices.map((p) => (p.variantId ?? '', p.variantName ?? 'Variant')),
    );
    final units = _distinct(
      prices.map((p) => (p.unitId ?? '', p.displayUnit)),
    );
    final currencies = _distinct(
      prices.map((p) => (p.currency ?? 'KES', p.displayCurrency)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _priceTypes.map((pt) {
            final selected = _priceType == pt.$1;
            return ChoiceChip(
              label: Text(pt.$2),
              selected: selected,
              onSelected: (_) =>
                  setState(() => _priceType = selected ? null : pt.$1),
            );
          }).toList(),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 8),
          _refineDropdown(
            label: 'Item',
            value: _itemId,
            options: items,
            onChanged: (v) => setState(() {
              _itemId = v;
              _variantId = null;
            }),
          ),
        ],
        if (variants.length > 1) ...[
          const SizedBox(height: 8),
          _refineDropdown(
            label: 'Variant',
            value: _variantId,
            options: variants,
            onChanged: (v) => setState(() => _variantId = v),
          ),
        ],
        if (units.length > 1) ...[
          const SizedBox(height: 8),
          _refineDropdown(
            label: 'Unit',
            value: _unitId,
            options: units,
            onChanged: (v) => setState(() => _unitId = v),
          ),
        ],
        if (currencies.length > 1) ...[
          const SizedBox(height: 8),
          _refineDropdown(
            label: 'Currency',
            value: _currency,
            options: currencies,
            onChanged: (v) => setState(() => _currency = v),
          ),
        ],
      ],
    );
  }

  Widget _refineDropdown({
    required String label,
    required String? value,
    required List<(String, String)> options,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        ...options.map(
          (o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)),
        ),
      ],
      onChanged: onChanged,
    );
  }

  // ───────────────────────────────────────────────────────────
  // PRICE LIST
  // ───────────────────────────────────────────────────────────
  Widget _buildPriceList(
    BuildContext context,
    List<DailyMarketPrice> prices,
    MarketPricesFilterState filter,
  ) {
    final filtered = _applyFilters(prices);

    if (filtered.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.trending_down,
        title: 'No verified prices',
        subtitle:
            'Select a county, sub-county, ward or market to view verified '
            'market prices.',
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _PriceCard(price: filtered[index]);
      },
    );
  }

  List<DailyMarketPrice> _applyFilters(List<DailyMarketPrice> prices) {
    var result = prices;
    if (_priceType != null && _priceType!.isNotEmpty) {
      result = result.where((p) => _matchesPriceType(p.priceType, _priceType!)).toList();
    }
    if (_itemId != null) {
      result = result.where((p) => p.itemId == _itemId).toList();
    }
    if (_variantId != null) {
      result = result.where((p) => p.variantId == _variantId).toList();
    }
    if (_unitId != null) {
      result = result.where((p) => p.unitId == _unitId).toList();
    }
    if (_currency != null) {
      result = result.where((p) => p.currency == _currency).toList();
    }
    return result;
  }

  bool _matchesPriceType(String? priceType, String selected) {
    final p = (priceType ?? '').toLowerCase().trim();
    if (selected == 'farm_gate') {
      return p == 'farm_gate' ||
          p == 'farm gate' ||
          p == 'producer' ||
          p == 'farm gate / producer';
    }
    return p == selected;
  }

  // ───────────────────────────────────────────────────────────
  // HELPERS
  // ───────────────────────────────────────────────────────────
  List<(String, String)> _distinct(Iterable<(String, String)> pairs) {
    final seen = <String>{};
    final result = <(String, String)>[];
    for (final pair in pairs) {
      final key = pair.$1.trim();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add((key, pair.$2.trim().isEmpty ? key : pair.$2.trim()));
    }
    result.sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
    return result;
  }
}

/// ============================================================
/// PRICE CARD
/// ============================================================
class _PriceCard extends ConsumerWidget {
  final DailyMarketPrice price;

  const _PriceCard({required this.price});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favourites = ref.watch(priceFavouritesProvider).value ?? const [];
    final isFav = favourites.any((f) {
      if (price.marketId != null && f.marketId != null) {
        return f.marketId == price.marketId;
      }
      if (price.locationId != null && f.locationId != null) {
        return f.locationId == price.locationId;
      }
      return false;
    });

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    price.productLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _toggleFavourite(ref, isFav),
                  icon: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? Colors.amber.shade700 : Colors.grey,
                  ),
                ),
              ],
            ),
            if (price.marketName != null || price.locationName != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [price.marketName, price.locationName]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price.avgPrice.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${price.displayCurrency}/${price.displayUnit}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _chip(Icons.trending_up, 'Avg ${price.avgPrice.toStringAsFixed(2)}'),
                if (price.minPrice != null)
                  _chip(Icons.arrow_downward, 'Min ${price.minPrice!.toStringAsFixed(2)}'),
                if (price.maxPrice != null)
                  _chip(Icons.arrow_upward, 'Max ${price.maxPrice!.toStringAsFixed(2)}'),
                if (price.observationCount > 0)
                  _chip(Icons.pie_chart_outline, '${price.observationCount} obs'),
                if (price.priceType != null && price.priceType!.isNotEmpty)
                  _chip(Icons.sell_outlined, price.priceType!),
                if (price.qualityGrade != null && price.qualityGrade!.isNotEmpty)
                  _chip(Icons.verified_outlined, price.qualityGrade!),
                if (price.recordedOn != null)
                  _chip(Icons.calendar_today, _formatDate(price.recordedOn!)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavourite(WidgetRef ref, bool isFav) async {
    final controller = ref.read(priceFavouritesControllerProvider.notifier);
    try {
      if (isFav) {
        final favourites =
            ref.read(priceFavouritesProvider).value ?? const [];
        String? existingId;
        for (final f in favourites) {
          if (price.marketId != null && f.marketId != null) {
            if (f.marketId == price.marketId) {
              existingId = f.id;
              break;
            }
          } else if (price.locationId != null && f.locationId != null) {
            if (f.locationId == price.locationId) {
              existingId = f.id;
              break;
            }
          }
        }
        if (existingId != null && existingId.isNotEmpty) {
          await controller.remove(existingId);
        }
      } else {
        await controller.add(
          marketId: price.marketId,
          locationId: price.locationId,
          itemId: price.itemId,
          variantId: price.variantId,
        );
      }
    } catch (_) {
      // Favourite toggle is best-effort; the read model is unaffected.
    }
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}
