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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/capabilities/application/capability_profile_provider.dart';
import 'package:famhub_app/core/capabilities/domain/capability.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

import '../../application/providers/active_business_provider.dart';
import '../../application/providers/my_businesses_provider.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/business_profile.dart';
import '../widgets/business_hub_inventory_tab.dart';
import '../widgets/business_hub_operations_widget.dart';
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
    blurb: 'Stock levels, movements and adjustments for this business '
        'will live here (commerce.stock_registry / '
        'commerce.stock_movements).',
  ),
  BusinessHubTabSpec(
    label: 'Procurement',
    icon: Icons.shopping_cart_outlined,
    capability: Capabilities.marketplaceOrders,
    blurb: 'Purchase orders and supplier sourcing will live here '
        '(commerce.purchase_orders / suppliers).',
  ),
  BusinessHubTabSpec(
    label: 'Sales',
    icon: Icons.trending_up,
    capability: Capabilities.marketplaceOrders,
    blurb: 'Orders, order lines and fulfilment for this business will '
        'live here (commerce.orders / commerce.order_items).',
  ),
  BusinessHubTabSpec(
    label: 'Listings',
    icon: Icons.storefront_outlined,
    capability: Capabilities.marketplaceListings,
    blurb: 'Marketplace catalog and listings for this business will live '
        'here (marketplace.listings).',
  ),
  BusinessHubTabSpec(
    label: 'Payments',
    icon: Icons.payments_outlined,
    capability: Capabilities.financeRecording,
    blurb: 'Payment transactions and business payments will live here '
        '(commerce.transactions / commerce.payments).',
  ),
  BusinessHubTabSpec(
    label: 'More',
    icon: Icons.more_horiz,
    blurb: 'Reserved for additional business operations: business '
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabSpecs.length, vsync: this);
    ref.invalidate(myBusinessesProvider);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessesAsync = ref.watch(myBusinessesProvider);
    final activeBusiness = ref.watch(activeBusinessProvider);

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ModuleHeaderWidget(
            title: 'Business Hub',
            subtitle: activeBusiness != null
                ? activeBusiness.name
                : 'Manage your commercial business entities',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: businessesAsync.when(
              loading: () => const LoadingStateWidget(
                message: 'Loading businesses...',
              ),
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
                return _buildWorkspace(businesses);
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
  Widget _buildWorkspace(List<BusinessEntity> businesses) {
    final profile = ref.watch(capabilityProfileProvider);

    bool capabilityEnabled(Capability? capability) {
      if (capability == null) return true;
      return profile?.hasCapability(capability.id) ?? false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Business / context header ──
        _ActiveBusinessCard(businesses: businesses),
        const SizedBox(height: 8),
        const _BusinessProfileLine(),
        const SizedBox(height: 12),

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
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (var i = 0; i < _tabSpecs.length; i++)
                _buildTabContent(_tabSpecs[i], i),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact, capability-aware tab label. Unavailable sections stay
  /// visible (stable structure) but are visibly muted.
  Widget _buildTabLabel(int index, bool Function(Capability?) capabilityEnabled) {
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
  /// Content is resolved per tab. Only the Inventory tab has a real
  /// implementation in this phase; the remaining tabs stay boundaries.
  Widget _buildTabContent(BusinessHubTabSpec spec, int index) {
    if (index == 0) return _buildOverviewContent();
    if (spec.label == 'Inventory') return const BusinessHubInventoryTab();
    return _buildBoundaryContent(spec);
  }

  /// ============================================================
  /// OVERVIEW TAB
  /// ============================================================
  Widget _buildOverviewContent() {
    return const SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: 12, bottom: 24),
      child: BusinessHubOperationsWidget(),
    );
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
/// ACTIVE BUSINESS CONTEXT CARD
/// ============================================================
class _ActiveBusinessCard extends ConsumerWidget {
  final List<BusinessEntity> businesses;

  const _ActiveBusinessCard({required this.businesses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = ref.watch(activeBusinessProvider);

    if (active == null) return const SizedBox.shrink();

    final canSwitch = businesses.length > 1;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.business_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          active.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TypeBadge(
                        label: active.entityType.label,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    active.isVerified
                        ? 'Verified business'
                        : 'Verification: ${_verificationLabel(active.verificationStatus)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (canSwitch)
              PopupMenuButton<String>(
                tooltip: 'Switch business',
                icon: const Icon(Icons.swap_horiz, size: 20),
                onSelected: (entityId) {
                  ref.read(activeBusinessIdProvider.notifier).select(entityId);
                },
                itemBuilder: (context) => [
                  for (final business in businesses)
                    PopupMenuItem<String>(
                      value: business.id,
                      child: Text(
                        business.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
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

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// ============================================================
/// BUSINESS PROFILE LINE (commerce.business_profiles)
/// ============================================================
class _BusinessProfileLine extends ConsumerWidget {
  const _BusinessProfileLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    if (active == null) return const SizedBox.shrink();

    final profileAsync = ref.watch(businessProfileProvider(active.id));
    final theme = Theme.of(context);

    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (BusinessProfile? profile) {
        final hasProfile = profile != null;
        final title = hasProfile ? profile.displayName : 'No seller profile yet';
        final subtitle = !hasProfile
            ? 'Business profile onboarding lands in a later phase.'
            : profile.isVerified
                ? 'Seller profile • Verified'
                : 'Seller profile • ${_statusLabel(profile.verificationStatus)}';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hasProfile
                ? Colors.green.withValues(alpha: 0.05)
                : Colors.orange.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                hasProfile ? Icons.verified_outlined : Icons.storefront_outlined,
                size: 18,
                color: hasProfile ? Colors.green : Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(String status) {
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
