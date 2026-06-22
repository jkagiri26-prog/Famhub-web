// ignore: dangling_library_doc_comments
/// ============================================================
/// FARM OPERATIONAL DASHBOARD — LIVE WIDGET COMPOSER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/presentation/dashboard/
///
/// ✅ RESPONSIBILITIES:
///   - Compose the real farm dashboard using live provider widgets
///   - Responsive grid layout for mobile-first usage
///   - Show all farm KPIs, charts, activity feed, alerts
///
/// ✅ CONSUMES EXISTING:
///   - farmDashboardProvider → summary + activities
///   - assetsProvider → stock/asset data
///   - farmContextProvider → farm selection
///   - marketplaceProvider → listings
///
/// ❌ Does NOT:
///   - Duplicate business logic
///   - Call Supabase directly
///   - Bypass repository/providers
///   - Recreate existing engine systems
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/farm_management/presentation/dashboard/widgets/production_trend_chart.dart';
import 'package:famhub_app/features/farm_management/presentation/dashboard/widgets/revenue_expense_chart.dart';
import 'package:famhub_app/features/farm_management/presentation/dashboard/widgets/inventory_valuation_card.dart';
import 'package:famhub_app/features/farm_management/presentation/dashboard/widgets/farm_health_indicator.dart';
import 'package:famhub_app/features/farm_management/presentation/dashboard/widgets/dashboard_activity_feed.dart';
import 'package:famhub_app/features/farm_management/presentation/dashboard/widgets/kpi_delta_indicators.dart';
import 'package:famhub_app/features/farm_management/presentation/dashboard/widgets/low_stock_alerts.dart';
import 'package:famhub_app/features/marketplace/presentation/widgets/marketplace_dashboard_widgets.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/widgets/runtime_health_widgets.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';

class FarmOperationalDashboard extends ConsumerWidget {
  const FarmOperationalDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmContext = ref.watch(farmContextProvider);
    final farmSelector = ref.watch(farmSelectorProvider);

    return ResponsiveWrapper(
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(farmDashboardProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // ── Header with Farm Selector ──
            _buildHeader(context, ref, farmContext, farmSelector),

            const SizedBox(height: 16),

            // ── Farm Health + KPIs ──
            const FarmHealthIndicator(),
            const SizedBox(height: 12),
            const KpiDeltaIndicators(),

            const SizedBox(height: 20),

            // ── Charts Section ──
            const SectionHeaderWidget(title: 'Production Analytics'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return const Row(
                    children: [
                      Expanded(child: ProductionTrendChart()),
                      SizedBox(width: 12),
                      Expanded(child: RevenueExpenseChart()),
                    ],
                  );
                }
                return const Column(
                  children: [
                    ProductionTrendChart(),
                    SizedBox(height: 12),
                    RevenueExpenseChart(),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Inventory Section ──
            const SectionHeaderWidget(title: 'Inventory & Assets'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return const Row(
                    children: [
                      Expanded(child: InventoryValuationCard()),
                      SizedBox(width: 12),
                      Expanded(child: LowStockAlerts()),
                    ],
                  );
                }
                return const Column(
                  children: [
                    InventoryValuationCard(),
                    SizedBox(height: 12),
                    LowStockAlerts(),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Marketplace Section ──
            const SectionHeaderWidget(title: 'Marketplace'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return const Row(
                    children: [
                      Expanded(child: ActiveListingsWidget()),
                      SizedBox(width: 12),
                      Expanded(child: MarketplaceSalesMetrics()),
                    ],
                  );
                }
                return const Column(
                  children: [
                    ActiveListingsWidget(),
                    SizedBox(height: 12),
                    MarketplaceSalesMetrics(),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Activity Section ──
            const SectionHeaderWidget(title: 'Recent Activity'),
            const SizedBox(height: 12),
            const DashboardActivityFeed(),

            const SizedBox(height: 20),

            // ── Runtime Section (Admin/Dev) ──
            const SectionHeaderWidget(title: 'Runtime Status'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return const Row(
                    children: [
                      Expanded(child: ModuleDegradationStatus()),
                      SizedBox(width: 12),
                      Expanded(child: RuntimeHealthIndicators()),
                    ],
                  );
                }
                return const Column(
                  children: [
                    ModuleDegradationStatus(),
                    SizedBox(height: 12),
                    RuntimeHealthIndicators(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    farmContext,
    farmSelector,
  ) {
    final theme = Theme.of(context);
    final farmName = farmContext.farm?.farmName ?? 'Farm Dashboard';
    final role = farmContext.role ?? 'Farmer';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                farmName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                role,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        if (farmSelector.farms.length > 1)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.swap_horiz_rounded,
              color: theme.colorScheme.primary,
            ),
            onSelected: (farmId) {
              ref.read(farmSelectorProvider.notifier).selectFarm(farmId);
            },
            itemBuilder: (context) {
              return farmSelector.farms.map((farm) {
                return PopupMenuItem(
                  value: farm.id,
                  child: Text(farm.farmName),
                );
              }).toList();
            },
          ),
      ],
    );
  }
}
