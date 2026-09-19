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
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/workspace/application/current_workspace_contexts_provider.dart';
import 'package:famhub_app/features/workspace_context/application/entity_context_refresh.dart';
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
            title: 'Trader',
            subtitle: activeBusiness != null
                ? activeBusiness.name
                : 'Manage your trading business entities',
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

    // Only entities AUTHORIZED in the current workspace may be switched to
    // (from `users.get_available_workspace_contexts()`), never an arbitrary
    // `core.entities` row.
    final contexts =
        ref.watch(currentWorkspaceContextsProvider).value ?? const [];
    final canSwitch = contexts.length > 1;

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
              IconButton(
                tooltip: 'Switch business',
                icon: const Icon(Icons.swap_horiz, size: 20),
                onPressed: () =>
                    _openEntitySwitcher(context, ref, contexts),
              ),
          ],
        ),
      ),
    );
  }

  /// Canonical same-workspace ENTITY switcher.
  ///
  /// Lists only the authorized contexts for the current workspace and
  /// activates the chosen one through the existing
  /// `users.activate_workspace_context(...)` path (via
  /// `ContextController.activateContextRow`). The sheet closes ONLY after a
  /// successful activation; on failure the previous entity is retained.
  Future<void> _openEntitySwitcher(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> contexts,
  ) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Switch business',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: contexts.length,
                itemBuilder: (_, index) {
                  final c = contexts[index];
                  final entityId = c['entity_id']?.toString();
                  final isActive = entityId != null &&
                      entityId == ref.read(contextProvider).entityId;
                  final subtitle = _contextSubtitle(c);
                  return ListTile(
                    leading: Icon(
                      isActive
                          ? Icons.check_circle
                          : Icons.business_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      _contextLabel(c),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: subtitle == null ? null : Text(subtitle),
                    onTap: () => _activateContext(sheetContext, ref, c),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _activateContext(
    BuildContext sheetContext,
    WidgetRef ref,
    Map<String, dynamic> c,
  ) async {
    final workspaceId = c['workspace_id']?.toString();
    final entityId = c['entity_id']?.toString();
    final roleId = c['role_id']?.toString();
    if (workspaceId == null ||
        workspaceId.isEmpty ||
        entityId == null ||
        entityId.isEmpty ||
        roleId == null ||
        roleId.isEmpty) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('This entity context is incomplete.')),
      );
      return;
    }

    final applied = await ref
        .read(contextProvider.notifier)
        .activateContextRow(
          workspaceId: workspaceId,
          entityId: entityId,
          roleId: roleId,
          businessProfileId: c['business_profile_id']?.toString(),
        );

    if (applied == null) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(
            content: Text('Could not switch business. Please try again.'),
          ),
        );
      }
      return; // keep the sheet open; previous entity retained
    }

    // Existing entity-scoped refresh mechanism.
    refreshEntityScopedProviders(ref);
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  String _contextLabel(Map<String, dynamic> c) {
    final named =
        c['entity_name'] ?? c['entity_display_name'] ?? c['entity_slug'] ?? c['name'];
    if (named != null && named.toString().trim().isNotEmpty) {
      return named.toString();
    }
    final id = c['entity_id']?.toString();
    for (final business in businesses) {
      if (business.id == id) return business.name;
    }
    return id ?? 'Entity';
  }

  String? _contextSubtitle(Map<String, dynamic> c) {
    final role =
        (c['role_name'] ?? c['active_mode'] ?? c['role_id'])?.toString();
    final businessProfile =
        (c['business_profile_name'] ?? c['supplier_name'])?.toString();
    final parts = <String>[
      if (role != null && role.isNotEmpty) role,
      if (businessProfile != null && businessProfile.isNotEmpty)
        businessProfile,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
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
