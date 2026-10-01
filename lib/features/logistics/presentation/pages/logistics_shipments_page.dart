import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/permission_denied_widget.dart';

import '../../application/providers/logistics_permission_provider.dart';
import '../../application/providers/logistics_shipment_provider.dart';
import '../../config/permissions.dart';
import '../../domain/models/logistics_dashboard_models.dart';
import '../logistics_display_utils.dart';
import 'logistics_shipment_detail_page.dart';

/// ============================================================
/// LOGISTICS — SHIPMENT LIST PAGE
/// ============================================================
///
/// Bounded shipment list. Opening a row pushes the shipment detail
/// experience using the same `Navigator.push` convention as the rest of
/// the app.
///
/// Architecture compliance:
/// - No Scaffold / AppBar / Drawer (shell owns them)
/// - ResponsiveWrapper enforced
/// - Loading / empty / error / permission states are always rendered
/// - Reads are already bounded by the repository (low-data requirement)
/// ============================================================
class LogisticsShipmentsPage extends ConsumerWidget {
  const LogisticsShipmentsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const LogisticsShipmentsPage(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entityContext = ref.watch(contextProvider);

    if (entityContext.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Preparing your shipments...'),
      );
    }

    if (entityContext.isGuest) {
      return const ResponsiveWrapper(
        child: PermissionDeniedWidget(
          title: 'Shipments locked',
          message: 'Sign in to view shipments for your active entity.',
        ),
      );
    }

    final permission = ref.watch(
      logisticsPermissionStatusProvider(LogisticsPermissions.viewShipments),
    );

    if (permission.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Checking shipment access...'),
      );
    }

    if (!permission.isAllowed) {
      return ResponsiveWrapper(
        child: PermissionDeniedWidget(
          title: permission.isUnavailable
              ? 'Shipments unavailable'
              : 'Shipments locked',
          message: permission.reason ??
              'Shipment access is not enabled for your role.',
        ),
      );
    }

    final shipments = ref.watch(logisticsShipmentsProvider);

    return ResponsiveWrapper(
      child: shipments.when(
        loading: () => const LoadingStateWidget(message: 'Loading shipments...'),
        error: (error, stackTrace) => ErrorStateWidget(
          title: 'Failed to Load',
          message: 'Could not load your shipments.',
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(logisticsShipmentsProvider),
          detailedError: error.toString(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(
              physics: const BouncingScrollPhysics(),
              children: const [
                SizedBox(height: 10),
                _BackBar(),
                SizedBox(height: 8),
                ModuleHeaderWidget(
                  title: 'Shipments',
                  subtitle: 'All shipments for your active entity',
                ),
                SizedBox(height: 16),
                EmptyStateWidget(
                  icon: Icons.local_shipping_outlined,
                  title: 'No shipments yet',
                  subtitle:
                      'Shipments for your active entity will appear here as '
                      'soon as they are created.',
                ),
              ],
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 10),
              const _BackBar(),
              const SizedBox(height: 8),
              ModuleHeaderWidget(
                title: 'Shipments',
                subtitle: '${rows.length} shipment'
                    '${rows.length == 1 ? '' : 's'} · tap for details',
                trailingIcon: Icons.refresh_rounded,
                onTrailingTap: () =>
                    ref.invalidate(logisticsShipmentsProvider),
              ),
              const SizedBox(height: 16),
              for (final shipment in rows) _ShipmentTile(shipment: shipment),
            ],
          );
        },
      ),
    );
  }
}

class _BackBar extends StatelessWidget {
  const _BackBar();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Back'),
      ),
    );
  }
}

class _ShipmentTile extends StatelessWidget {
  final LogisticsShipment shipment;

  const _ShipmentTile({required this.shipment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference =
        shipment.trackingNumber ?? '#${logisticsShortId(shipment.id)}';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        LogisticsShipmentDetailPage.route(shipmentId: shipment.id),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              shipment.isActive
                  ? Icons.local_shipping_outlined
                  : Icons.inventory_2_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shipment.statusLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shipment.carrier == null || shipment.carrier!.isEmpty
                        ? 'Carrier not assigned'
                        : shipment.carrier!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Updated ${logisticsTimestamp(shipment.updatedAt)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  reference,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
