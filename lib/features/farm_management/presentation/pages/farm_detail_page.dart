import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/activity_feed_widget.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/activities_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/production_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/assets_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/crops_provider.dart';

import 'package:famhub_app/features/farm_management/presentation/pages/fields_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/assets_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/production_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/activities_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/crops_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/livestock_page.dart';

/// Farm Detail Page with operational tabs.
///
/// Route: /farm/:id
/// Provides a full operational view of a single farm.
///
/// Shell-compliant: no Scaffold, no AppBar (owned by UnifiedAppShellV2).
/// TabBar is rendered as page content, not inside AppBar.
class FarmDetailPage extends ConsumerStatefulWidget {
  final String farmId;
  final String farmName;

  const FarmDetailPage({
    super.key,
    required this.farmId,
    required this.farmName,
  });

  @override
  ConsumerState<FarmDetailPage> createState() => _FarmDetailPageState();
}

class _FarmDetailPageState extends ConsumerState<FarmDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Set the farm context to this farm
    Future.microtask(() {
      ref.read(farmSelectorProvider.notifier).selectFarm(widget.farmId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const _tabs = [
    Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 18)),
    Tab(text: 'Crops', icon: Icon(Icons.grass, size: 18)),
    Tab(text: 'Livestock', icon: Icon(Icons.pets, size: 18)),
    Tab(text: 'Fields', icon: Icon(Icons.landscape, size: 18)),
    Tab(text: 'Assets', icon: Icon(Icons.precision_manufacturing, size: 18)),
    Tab(text: 'Activities', icon: Icon(Icons.list_alt, size: 18)),
    Tab(text: 'Production', icon: Icon(Icons.shopping_basket, size: 18)),
  ];

  @override
  Widget build(BuildContext context) {
    final contextState = ref.watch(farmContextProvider);

    // No Scaffold or AppBar — these are owned by UnifiedAppShellV2.
    // TabBar becomes part of page content.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title section (replaces AppBar title) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.farmName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (contextState.farm?.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    contextState.farm!.description!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── TabBar as page content ──
        SizedBox(
          width: MediaQuery.of(context).size.width,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: _tabs,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Tab content ──
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(farmId: widget.farmId, tabController: _tabController),
              const CropsPage(),
              const LivestockPage(),
              const FieldsPage(),
              const AssetsPage(),
              const ActivitiesPage(),
              const ProductionRecordingPage(),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  final String farmId;
  final TabController? tabController;

  const _OverviewTab({required this.farmId, this.tabController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(farmDashboardProvider);
    final contextState = ref.watch(farmContextProvider);

    return dashboardAsync.when(
      loading: () => const ShellPageContent(
        title: 'Dashboard',
        subtitle: 'Loading farm data...',
        child: LoadingStateWidget(useSkeleton: true),
      ),
      error: (err, stack) => ShellPageContent(
        title: 'Dashboard',
        subtitle: 'Failed to load farm data',
        child: ErrorStateWidget(
          title: 'Error Loading Dashboard',
          message: err.toString(),
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(farmDashboardProvider),
        ),
      ),
      data: (state) {
        final summary = state.summary;
        final activities = state.todayActivities;

        // Convert activities to feed items
        final feedItems = activities.map((act) => ActivityItem(
          title: 'Activity recorded',
          subtitle: act.notes,
          icon: Icons.event_note,
          color: Colors.blue,
          timestamp: _formatTimestamp(act.performedAt),
        )).toList();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Farm Info Card ──
              Card(
                elevation: 0,
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
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.agriculture,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contextState.farm?.farmName ?? 'Farm',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (contextState.farm?.size != null)
                                      Text(
                                        '${contextState.farm!.size!.toStringAsFixed(1)} ha',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    if (contextState.farm?.size != null)
                                      const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (contextState.farm?.isActive ?? true)
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        (contextState.farm?.isActive ?? true) ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: (contextState.farm?.isActive ?? true)
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── KPI Cards ──
              Text(
                'Performance Metrics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              AdaptiveContentGrid(
                items: [
                  KPICard(
                    label: 'Total Production',
                    value: summary.totalProduction.toStringAsFixed(1),
                    icon: Icons.inventory_2,
                    iconColor: Colors.green,
                  ),
                  KPICard(
                    label: 'Total Sales',
                    value: '\$${summary.totalSales.toStringAsFixed(0)}',
                    icon: Icons.trending_up,
                    iconColor: Colors.blue,
                  ),
                  KPICard(
                    label: 'Total Expenses',
                    value: '\$${summary.totalExpenses.toStringAsFixed(0)}',
                    icon: Icons.money_off,
                    iconColor: Colors.red,
                  ),
                  KPICard(
                    label: 'Stock Value',
                    value: '\$${summary.stockValue.toStringAsFixed(0)}',
                    icon: Icons.inventory,
                    iconColor: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Today's Activities ──
              Row(
                children: [
                  Text(
                    "Today's Activities",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      tabController?.animateTo(5); // Switch to Activities tab
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View All', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ActivityFeedWidget(
                activities: feedItems,
                emptyTitle: 'No activities today',
                emptySubtitle: 'Start recording farm operations.',
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}