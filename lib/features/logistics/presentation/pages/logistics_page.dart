import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/permission_denied_widget.dart';

import '../../application/providers/logistics_dashboard_provider.dart';
import '../widgets/logistics_actions_section_widget.dart';
import '../widgets/logistics_shipments_section_widget.dart';
import '../widgets/logistics_tracking_section_widget.dart';
import '../widgets/logistics_transport_section_widget.dart';
import 'logistics_shipments_page.dart';
import 'logistics_tracking_page.dart';

/// ============================================================
/// LOGISTICS PAGE — module entry / dashboard
/// ============================================================
///
/// FAMHUB Logistics module.
///
/// Architecture compliance:
/// - No Scaffold / AppBar / Drawer / BottomNavigationBar (shell owns them)
/// - ResponsiveWrapper enforced
/// - Entity context comes from the existing FAMHUB context mechanism
/// - Backend RLS stays authoritative — no client-side ownership id
/// - Loading / empty / error / permission states are always rendered
///
/// GPS is NOT collected here. The Tracking section only surfaces
/// backend tracking-session metadata and links into the tracking
/// experience; device capture lives in the shipment detail page and is
/// only started by an explicit driver action.
/// ============================================================
class LogisticsPage extends ConsumerStatefulWidget {
  const LogisticsPage({super.key});

  @override
  ConsumerState<LogisticsPage> createState() => _LogisticsPageState();
}

class _LogisticsPageState extends ConsumerState<LogisticsPage> {
  final GlobalKey _trackingKey = GlobalKey();

  void _openShipments() {
    Navigator.of(context).push(LogisticsShipmentsPage.route());
  }

  void _openTracking() {
    Navigator.of(context).push(LogisticsTrackingPage.route());
  }

  void _refresh() {
    ref.invalidate(logisticsDashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final entityContext = ref.watch(contextProvider);

    if (entityContext.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(
          message: 'Preparing your Logistics workspace...',
        ),
      );
    }

    if (entityContext.isGuest) {
      return const ResponsiveWrapper(
        child: PermissionDeniedWidget(
          title: 'Logistics locked',
          message:
              'Sign in to view shipments, transport and tracking for your '
              'active entity.',
        ),
      );
    }

    final dashboard = ref.watch(logisticsDashboardProvider);

    return ResponsiveWrapper(
      child: dashboard.when(
        loading: () => const LoadingStateWidget(
          message: 'Loading logistics...',
        ),
        error: (error, stackTrace) => ErrorStateWidget(
          title: 'Failed to Load',
          message: 'Could not load your Logistics dashboard.',
          retryLabel: 'Retry',
          onRetry: _refresh,
          detailedError: error.toString(),
        ),
        data: (snapshot) => ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const SizedBox(height: 10),

            /// MODULE HEADER
            ModuleHeaderWidget(
              title: 'Logistics',
              subtitle: 'Shipments • Transport • Tracking',
              trailingIcon: Icons.refresh_rounded,
              onTrailingTap: _refresh,
            ),

            const SizedBox(height: 16),

            /// KPI ROW
            AdaptiveContentGrid(
              items: [
                KPICard(
                  label: 'Active shipments',
                  value: '${snapshot.activeShipments.length}',
                  icon: Icons.local_shipping_outlined,
                ),
                KPICard(
                  label: 'Assigned transport',
                  value: '${snapshot.activeAssignments.length}',
                  icon: Icons.person_pin_circle_outlined,
                ),
                KPICard(
                  label: 'Pending assignments',
                  value: '${snapshot.pendingAssignments.length}',
                  icon: Icons.schedule_outlined,
                ),
              ],
              mobileColumns: 1,
              tabletColumns: 3,
              desktopColumns: 3,
            ),

            const SizedBox(height: 20),

            /// SHIPMENTS
            LogisticsShipmentsSectionWidget(snapshot: snapshot),

            const SizedBox(height: 20),

            /// TRANSPORT
            LogisticsTransportSectionWidget(snapshot: snapshot),

            const SizedBox(height: 20),

            /// TRACKING (future GPS home — read-only for now)
            KeyedSubtree(
              key: _trackingKey,
              child: LogisticsTrackingSectionWidget(snapshot: snapshot),
            ),

            const SizedBox(height: 20),

            /// ACTIONS (permission-gated)
            LogisticsActionsSectionWidget(
              onViewShipments: _openShipments,
              onAssignTransport: _openShipments,
              onViewTracking: _openTracking,
            ),
          ],
        ),
      ),
    );
  }
}
