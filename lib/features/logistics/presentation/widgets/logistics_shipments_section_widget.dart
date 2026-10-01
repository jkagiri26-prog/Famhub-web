import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';
import 'package:famhub_app/shared/widgets/cards/info_tile_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';

import '../../domain/models/logistics_dashboard_models.dart';
import '../logistics_display_utils.dart';
import '../pages/logistics_shipment_detail_page.dart';
import '../pages/logistics_shipments_page.dart';
import 'logistics_active_shipment_card_widget.dart';

/// Shipments section: active + recent, both already bounded by the
/// repository so the page never downloads full shipment history.
class LogisticsShipmentsSectionWidget extends StatelessWidget {
  final LogisticsDashboardSnapshot snapshot;

  const LogisticsShipmentsSectionWidget({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final active = snapshot.activeShipments;
    final recent = snapshot.recentShipments;

    if (active.isEmpty && recent.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeaderWidget(title: 'Shipments'),
          SizedBox(height: 8),
          EmptyStateWidget(
            icon: Icons.local_shipping_outlined,
            title: 'No shipments yet',
            subtitle:
                'Shipments for your active entity will appear here as soon '
                'as they are created.',
          ),
        ],
      );
    }

    // Most recent rows first, without repeating what the active cards
    // already show.
    final activeIds = active.map((s) => s.id).toSet();
    final recentRows =
        recent.where((s) => !activeIds.contains(s.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeaderWidget(title: 'Shipments'),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                LogisticsShipmentsPage.route(),
              ),
              icon: const Icon(Icons.list_alt_outlined, size: 16),
              label: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 4),

        if (active.isNotEmpty) ...[
          Text(
            _statusSummary(active),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          AdaptiveContentGrid(
            items: [
              for (final shipment in active)
                _ActiveShipmentTile(shipment: shipment),
            ],
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
          ),
          const SizedBox(height: 16),
        ],

        if (recentRows.isNotEmpty) ...[
          const SectionHeaderWidget(title: 'Recent shipments'),
          const SizedBox(height: 8),
          for (final shipment in recentRows)
            InfoTileWidget(
              icon: Icons.inventory_2_outlined,
              label: shipment.statusLabel,
              value: shipment.trackingNumber?.isNotEmpty == true
                  ? shipment.trackingNumber!
                  : '#${logisticsShortId(shipment.id)}',
              onTap: () => Navigator.of(context).push(
                LogisticsShipmentDetailPage.route(shipmentId: shipment.id),
              ),
            ),
        ],

        if (snapshot.isTruncated)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Showing the latest shipments only.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  /// Compact shipment-status breakdown for the active window.
  String _statusSummary(List<LogisticsShipment> active) {
    final counts = <String, int>{};
    for (final shipment in active) {
      final label = shipment.statusLabel;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts.entries
        .map((entry) => '${entry.value} ${entry.key.toLowerCase()}')
        .join('  ·  ');
  }
}

/// Tappable wrapper so a dashboard shipment opens its detail experience.
class _ActiveShipmentTile extends StatelessWidget {
  final LogisticsShipment shipment;

  const _ActiveShipmentTile({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        LogisticsShipmentDetailPage.route(shipmentId: shipment.id),
      ),
      borderRadius: BorderRadius.circular(12),
      child: LogisticsActiveShipmentCardWidget(shipment: shipment),
    );
  }
}
