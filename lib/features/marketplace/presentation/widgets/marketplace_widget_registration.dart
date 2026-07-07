/// ============================================================
/// MARKETPLACE — WIDGET REGISTRATION BOOTSTRAP (PHASE D)
/// ============================================================
///
/// Registers all marketplace dashboard widgets with live data.
/// Each widget builder connects to its own marketplace live provider.
///
/// Architecture:
///   WidgetRegistry.register(marketplace_kpi_card, builder) → MarketplaceKpiWidget → marketplaceKpiDataProvider
///
/// Every widget:
///   - Uses ModuleErrorBoundary for graceful failure
///   - Connects to a specific live provider
///   - Handles loading/error/data states
///   - Reports metrics to observability
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/features/marketplace/application/providers/marketplace_live_providers.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';

/// ============================================================
/// BOOTSTRAP ALL MARKETPLACE WIDGETS
/// ============================================================
void bootstrapMarketplaceWidgets() {
  WidgetRegistry.register(
    widgetKey: 'marketplace_kpi_card',
    builder: () => const _MarketplaceKpiWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'marketplace_featured_listings',
    builder: () => const _MarketplaceFeaturedWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'marketplace_sales_metrics',
    builder: () => const _MarketplaceSalesMetricsWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'marketplace_listing_performance',
    builder: () => const _MarketplaceListingPerformanceWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'marketplace_quick_sell',
    builder: () => const _MarketplaceQuickSellWidget(),
  );
}

// ════════════════════════════════════════════════════════════════
// MARKETPLACE KPI WIDGET
// ════════════════════════════════════════════════════════════════
class _MarketplaceKpiWidget extends ConsumerWidget {
  const _MarketplaceKpiWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync = ref.watch(marketplaceKpiDataProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'marketplace_kpi_card',
      displayName: 'Marketplace KPIs',
      child: kpiAsync.when(
        loading: () => const _MiniLoader(),
        error: (_, __) => const _MiniError('Failed to load KPIs'),
        data: (kpi) => Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Marketplace KPIs', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _kpiRow('Total Listings', '${kpi['total_listings'] ?? 0}', Colors.blue),
              const SizedBox(height: 6),
              _kpiRow('Active', '${kpi['active_listings'] ?? 0}', Colors.green),
              const SizedBox(height: 6),
              _kpiRow('Total Value', '\$${(kpi['total_value'] as num?)?.toStringAsFixed(2) ?? '0.00'}', Colors.teal),
              const SizedBox(height: 6),
              _kpiRow('Avg Price', '\$${(kpi['avg_price'] as num?)?.toStringAsFixed(2) ?? '0.00'}', Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MARKETPLACE FEATURED LISTINGS WIDGET
// ════════════════════════════════════════════════════════════════
class _MarketplaceFeaturedWidget extends ConsumerWidget {
  const _MarketplaceFeaturedWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredAsync = ref.watch(marketplaceFeaturedListingsProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'marketplace_featured_listings',
      displayName: 'Featured Listings',
      child: featuredAsync.when(
        loading: () => const _MiniLoader(),
        error: (_, __) => const _MiniError('Failed to load listings'),
        data: (listings) => Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Featured Listings', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (listings.isEmpty)
                _emptyState('No listings available')
              else
                ...listings.take(3).map((l) => _listingTile(l, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listingTile(Listing listing, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.store, size: 14, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
                Text('\$${listing.pricePerUnit.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text(msg, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MARKETPLACE SALES METRICS WIDGET
// ════════════════════════════════════════════════════════════════
class _MarketplaceSalesMetricsWidget extends ConsumerWidget {
  const _MarketplaceSalesMetricsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(marketplaceSalesMetricsProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'marketplace_sales_metrics',
      displayName: 'Sales Metrics',
      child: metricsAsync.when(
        loading: () => const _MiniLoader(),
        error: (_, __) => const _MiniError('Failed to load sales metrics'),
        data: (metrics) => Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales Metrics', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                _metricTile('Total Sales', '${metrics['total_sales'] ?? 0}', Icons.shopping_cart, Colors.blue, theme),
                const SizedBox(width: 8),
                _metricTile('Revenue', '\$${(metrics['total_revenue'] as num?)?.toStringAsFixed(0) ?? '0'}', Icons.attach_money, Colors.green, theme),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _metricTile('Pending', '${metrics['pending_approvals'] ?? 0}', Icons.hourglass_empty, Colors.orange, theme),
                const SizedBox(width: 8),
                _metricTile('Avg Sale', '\$${(metrics['avg_sale_price'] as num?)?.toStringAsFixed(0) ?? '0'}', Icons.trending_up, Colors.teal, theme),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MARKETPLACE LISTING PERFORMANCE WIDGET
// ════════════════════════════════════════════════════════════════
class _MarketplaceListingPerformanceWidget extends ConsumerWidget {
  const _MarketplaceListingPerformanceWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(marketplaceListingPerformanceProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'marketplace_listing_performance',
      displayName: 'Listing Performance',
      child: performanceAsync.when(
        loading: () => const _MiniLoader(),
        error: (_, __) => const _MiniError('Failed to load performance data'),
        data: (performance) => Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Top Performers', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (performance.isEmpty)
                _emptyState('No listings yet')
              else
                ...performance.take(4).map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p['title'] as String? ?? 'Unknown',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${p['views']} views', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text(msg, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MARKETPLACE QUICK SELL WIDGET
// ════════════════════════════════════════════════════════════════
class _MarketplaceQuickSellWidget extends ConsumerWidget {
  const _MarketplaceQuickSellWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(marketplaceQuickSellProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'marketplace_quick_sell',
      displayName: 'Quick Sell',
      child: listingsAsync.when(
        loading: () => const _MiniLoader(),
        error: (_, __) => const _MiniError('Failed to load listings'),
        data: (listings) => Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Sell', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.sell, size: 32, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('${listings.length} active listings', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Tap to manage your listings', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ════════════════════════════════════════════════════════════════
class _MiniLoader extends StatelessWidget {
  const _MiniLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _MiniError extends StatelessWidget {
  final String message;
  const _MiniError(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(message, style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
    );
  }
}
