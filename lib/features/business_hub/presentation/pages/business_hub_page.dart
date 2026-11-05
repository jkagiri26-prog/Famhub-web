/// ============================================================
/// BUSINESS HUB PAGE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/business_hub/presentation/pages/ = module pages
///
/// Business Hub workspace page with a STABLE top tab navigation:
///
///   1. Overview (default)
///   2. Inventory
///   3. Procurement
///   4. Sales
///   5. Listings
///   6. Payments
///   7. More
///
/// Architecture:
///   Business Entity → Business Profile → Context → Capabilities →
///   Business Operations
///
/// Tabs are the stable navigation structure of Business Hub. There are
/// NO per-type tabs/dashboards (trader, aggregator, retailer, factory,
/// processor, agrovet, exporter, ...). Business type only influences
/// which capabilities/data are available INSIDE the appropriate tabs.
///
/// Capability awareness:
///   - Tabs are never dynamically added/removed (avoids navigation
///     jumping). Unavailable sections remain visible but render as
///     disabled/empty rather than fabricating data.
///   - Tab availability is evaluated with the Capability Framework; the
///     per-tab capability ids map to existing contracts only.
///
/// Content for this phase:
///   - Overview        → current Business Hub overview (operations)
///   - Inventory ...   → section boundaries only (no backend operations)
///   - More            → reserved for profile / facilities / members /
///                       settings / future capabilities
///
/// Routing/state: the selected tab lives in this page (TabController);
/// no extra routes are created.
/// ============================================================
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/capabilities/application/capability_profile_provider.dart';
import 'package:famhub_app/core/capabilities/domain/capability.dart';
import 'package:famhub_app/core/navigation/resize_optimizer.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/layouts/workspace_section_nav.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

import '../../application/providers/active_business_provider.dart';
import '../../application/providers/my_businesses_provider.dart';
import '../widgets/business_hub_inventory_tab.dart';
import '../widgets/business_hub_listings_tab.dart';
import '../widgets/business_hub_more_tab.dart';
import '../widgets/business_hub_overview_tab.dart';
import '../widgets/business_hub_payments_tab.dart';
import '../widgets/business_hub_procurement_tab.dart';
import '../widgets/business_hub_sales_tab.dart';
import '../widgets/business_hub_section_boundary.dart';

/// ============================================================
/// BUSINESS HUB TABS (STABLE NAVIGATION STRUCTURE)
/// ============================================================

/// The canonical Business Hub tab set.
///
/// Do NOT add per-business-type tabs here. A business's type/role
/// decides capabilities and data shown inside a tab, not which tabs
/// exist. `capability` maps the tab to an existing Capability contract
/// (null = always available, e.g. Overview/More).
class BusinessHubTabSpec {
  final String label;
  final IconData icon;
  final Capability? capability;
  final String blurb;

  const BusinessHubTabSpec({
    required this.label,
    required this.icon,
    this.capability,
    required this.blurb,
  });
}

const _traderHistoryExtraKey = '_traderHistory';

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

const List<BusinessHubTabSpec> _tabSpecs = [
  BusinessHubTabSpec(
    label: 'Overview',
    icon: Icons.dashboard_outlined,
    blurb: 'Capability-driven overview for the active business.',
  ),
  BusinessHubTabSpec(
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    capability: Capabilities.inventoryStock,
    blurb:
        'Stock levels, movements and adjustments for this business '
        'will live here (commerce.stock_registry / '
        'commerce.stock_movements).',
  ),
  BusinessHubTabSpec(
    label: 'Procurement',
    icon: Icons.shopping_cart_outlined,
    capability: Capabilities.marketplaceOrders,
    blurb:
        'Purchase orders and supplier sourcing will live here '
        '(commerce.purchase_orders / suppliers).',
  ),
  BusinessHubTabSpec(
    label: 'Sales',
    icon: Icons.trending_up,
    capability: Capabilities.marketplaceOrders,
    blurb:
        'Orders, order lines and fulfilment for this business will '
        'live here (commerce.orders / commerce.order_items).',
  ),
  BusinessHubTabSpec(
    label: 'Listings',
    icon: Icons.storefront_outlined,
    capability: Capabilities.marketplaceListings,
    blurb:
        'Marketplace catalog and listings for this business will live '
        'here (marketplace.listings).',
  ),
  BusinessHubTabSpec(
    label: 'Payments',
    icon: Icons.payments_outlined,
    capability: Capabilities.financeRecording,
    blurb:
        'Payment transactions and business payments will live here '
        '(commerce.transactions / commerce.payments).',
  ),
  BusinessHubTabSpec(
    label: 'More',
    icon: Icons.more_horiz,
    blurb:
        'Reserved for additional business operations: business '
        'profile, facilities/locations, members/team, settings and '
        'other future capabilities.',
  ),
];

/// ============================================================
/// PAGE
/// ============================================================
class BusinessHubPage extends ConsumerStatefulWidget {
  const BusinessHubPage({super.key});

  @override
  ConsumerState<BusinessHubPage> createState() => _BusinessHubPageState();
}

class _BusinessHubPageState extends ConsumerState<BusinessHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  GoRouter? _router;
  bool _historyReady = false;
  bool _restoringHistory = false;
  bool _historyRecordScheduled = false;
  int _historyRestoreGeneration = 0;
  int? _lastHistoryTab;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabSpecs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    ref.invalidate(myBusinessesProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onRouterChanged);
      _router = router;
      router.routerDelegate.addListener(_onRouterChanged);
    }
    if (_historyReady) return;
    _historyReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreFromRoute(initial: true);
    });
  }

  @override
  void dispose() {
    _historyRestoreGeneration++;
    _router?.routerDelegate.removeListener(_onRouterChanged);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onRouterChanged() => _restoreFromRoute();

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _scheduleBrowserHistoryRecord();
  }

  void _scheduleBrowserHistoryRecord() {
    if (!kIsWeb ||
        !_historyReady ||
        _restoringHistory ||
        _historyRecordScheduled) {
      return;
    }
    _historyRecordScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _historyRecordScheduled = false;
      if (!mounted || _restoringHistory) return;
      _writeBrowserHistory();
    });
  }

  void _writeBrowserHistory({bool replace = false}) {
    final router = _router;
    if (!kIsWeb ||
        !_historyReady ||
        router == null ||
        router.routerDelegate.currentConfiguration.uri.path != '/trader') {
      return;
    }
    final tabIndex = _tabController.index;
    if (!replace && _lastHistoryTab == tabIndex) return;

    final configuration = router.routerDelegate.currentConfiguration;
    final routeExtra = _stringKeyedMap(configuration.extra);
    final extra = {
      ...routeExtra,
      _traderHistoryExtraKey: {
        'workspaceId': ref.read(activeWorkspaceProvider).workspaceId,
        'tabIndex': tabIndex,
      },
    };
    _lastHistoryTab = tabIndex;
    final uri = configuration.uri;
    if (replace) {
      Router.neglect(context, () => router.go(uri.toString(), extra: extra));
    } else {
      Router.navigate(context, () => router.go(uri.toString(), extra: extra));
    }
  }

  void _restoreFromRoute({bool initial = false}) {
    final router = _router;
    if (!kIsWeb ||
        !_historyReady ||
        !mounted ||
        router == null ||
        router.routerDelegate.currentConfiguration.uri.path != '/trader') {
      return;
    }
    final configuration = router.routerDelegate.currentConfiguration;
    final routeExtra = _stringKeyedMap(configuration.extra);
    final snapshot = _stringKeyedMap(routeExtra[_traderHistoryExtraKey]);
    final workspaceId = ref.read(activeWorkspaceProvider).workspaceId;
    if (snapshot['workspaceId'] != workspaceId) {
      if (initial) _writeBrowserHistory(replace: true);
      return;
    }
    final targetTab = snapshot['tabIndex'] is int
        ? snapshot['tabIndex']! as int
        : 0;
    if (targetTab < 0 || targetTab >= _tabSpecs.length) return;
    if (targetTab == _tabController.index) {
      _lastHistoryTab = targetTab;
      return;
    }
    final generation = ++_historyRestoreGeneration;
    _restoringHistory = true;
    _lastHistoryTab = targetTab;
    _tabController.animateTo(targetTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _historyRestoreGeneration) return;
      _restoringHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final businessesAsync = ref.watch(myBusinessesProvider);
    final activeBusiness = ref.watch(activeBusinessProvider);

    // Prefer the created Business Profile name (supplier_name) over the
    // generic core.entities name. The profile is the user-facing identity.
    final activeProfile = activeBusiness == null
        ? null
        : ref.watch(businessProfileProvider(activeBusiness.id)).value;
    final headerSubtitle =
        activeProfile?.displayName ??
        activeBusiness?.name ??
        'Manage your trading business entities';

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ModuleHeaderWidget(title: 'Trader', subtitle: headerSubtitle),
          const SizedBox(height: 12),
          Expanded(
            child: businessesAsync.when(
              loading: () =>
                  const LoadingStateWidget(message: 'Loading businesses...'),
              error: (e, _) => ErrorStateWidget(
                title: 'Failed to Load',
                message: 'Could not load your businesses.',
                retryLabel: 'Retry',
                onRetry: () => ref.invalidate(myBusinessesProvider),
                detailedError: e.toString(),
              ),
              data: (businesses) {
                if (businesses.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.business_center_outlined,
                    title: 'No businesses yet',
                    subtitle: 'Create or link a business to get started.',
                  );
                }
                return _buildWorkspace();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// WORKSPACE (data state)
  /// ============================================================
  Widget _buildWorkspace() {
    final profile = ref.watch(capabilityProfileProvider);

    bool capabilityEnabled(Capability? capability) {
      if (capability == null) return true;
      return profile?.hasCapability(capability.id) ?? false;
    }

    // Desktop/ultraWide: secondary vertical section navigation. Tablet/
    // mobile: the existing horizontal TabBar. Both drive the SAME
    // TabController, so history behaviour is unchanged.
    final deviceType = ref.watch(breakpointProvider).deviceType;
    final isDesktop = deviceType == 'desktop' || deviceType == 'ultraWide';

    final tabView = TabBarView(
      controller: _tabController,
      children: [
        for (var i = 0; i < _tabSpecs.length; i++)
          _buildTabContent(_tabSpecs[i], i),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Business identity (single, non-interactive) ──
        // The app-bar Entity selector is the ONLY Entity switcher; this
        // line merely identifies the Business Profile operating within the
        // active Entity. It is not a switcher and owns no selection state.
        const _BusinessIdentityLine(),
        const SizedBox(height: 12),

        if (isDesktop)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSectionNav(
                  controller: _tabController,
                  sections: [
                    for (final spec in _tabSpecs)
                      WorkspaceSectionNavItem(
                        label: spec.label,
                        icon: spec.icon,
                        enabled: capabilityEnabled(spec.capability),
                      ),
                  ],
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(child: tabView),
              ],
            ),
          )
        else ...[
          // ── Top tab navigation (stable) ──
          SizedBox(
            width: double.infinity,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                for (var i = 0; i < _tabSpecs.length; i++)
                  Tab(child: _buildTabLabel(i, capabilityEnabled)),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Tab content ──
          Expanded(child: tabView),
        ],
      ],
    );
  }

  /// Compact, capability-aware tab label. Unavailable sections stay
  /// visible (stable structure) but are visibly muted.
  Widget _buildTabLabel(
    int index,
    bool Function(Capability?) capabilityEnabled,
  ) {
    final spec = _tabSpecs[index];
    final selected = index == _tabController.index;
    final enabled = capabilityEnabled(spec.capability);
    final theme = Theme.of(context);

    final Color color;
    if (selected) {
      color = theme.colorScheme.primary;
    } else if (!enabled) {
      color = Colors.grey.shade400;
    } else {
      color = Colors.grey.shade600;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(spec.icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          spec.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// ============================================================
  /// TAB CONTENT DISPATCH
  /// ============================================================
  ///
  /// Content is resolved per tab. Inventory, Procurement, Sales and
  /// Listings have real implementations in this phase; the remaining
  /// tabs stay boundaries.
  Widget _buildTabContent(BusinessHubTabSpec spec, int index) {
    if (index == 0) return _buildOverviewContent();
    if (spec.label == 'Inventory') return const BusinessHubInventoryTab();
    if (spec.label == 'Procurement') {
      return const BusinessHubProcurementTab();
    }
    if (spec.label == 'Sales') return const BusinessHubSalesTab();
    if (spec.label == 'Listings') return const BusinessHubListingsTab();
    if (spec.label == 'Payments') return const BusinessHubPaymentsTab();
    if (spec.label == 'More') return const BusinessHubMoreTab();
    return _buildBoundaryContent(spec);
  }

  /// ============================================================
  /// OVERVIEW TAB
  /// ============================================================
  Widget _buildOverviewContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: BusinessHubOverviewTab(onOpenTab: _openTab),
    );
  }

  /// Switch to an existing Business Hub tab by label (no new routes).
  void _openTab(String label) {
    for (var i = 0; i < _tabSpecs.length; i++) {
      if (_tabSpecs[i].label == label) {
        _tabController.animateTo(i);
        return;
      }
    }
  }

  /// ============================================================
  /// BOUNDARY TABS (inventory / procurement / sales / listings /
  /// payments / more)
  /// ============================================================
  Widget _buildBoundaryContent(BusinessHubTabSpec spec) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: BusinessHubSectionBoundary(
        title: spec.label,
        icon: spec.icon,
        capability: spec.capability,
        blurb: spec.blurb,
      ),
    );
  }
}

/// ============================================================
/// BUSINESS IDENTITY LINE (single, non-interactive)
/// ============================================================
///
/// Identifies the Business Profile (`commerce.business_profiles`) that
/// operates within the active Entity. Entity/context switching is owned
/// exclusively by the app-bar Entity selector — this is display-only and
/// owns no selection state.
class _BusinessIdentityLine extends ConsumerWidget {
  const _BusinessIdentityLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = ref.watch(activeBusinessProvider);
    if (active == null) return const SizedBox.shrink();

    final profile = ref.watch(businessProfileProvider(active.id)).value;
    final verified = profile?.isVerified ?? false;
    final status = verified
        ? 'Verified'
        : _verificationLabel(profile?.verificationStatus ?? 'pending');

    return Row(
      children: [
        Icon(
          verified ? Icons.verified_outlined : Icons.hourglass_empty,
          size: 14,
          color: verified ? Colors.green : Colors.orange.shade700,
        ),
        const SizedBox(width: 6),
        Text(
          'Verification: $status',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _verificationLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'suspended':
        return 'Suspended';
      default:
        return 'Pending';
    }
  }
}
