import 'package:flutter/material.dart';

import '../../domain/models/logistics_dashboard_models.dart';
import '../logistics_display_utils.dart';

/// Single active shipment card for the Logistics dashboard.
///
/// Reads only the bounded shipment fields exposed by the repository —
/// no cargo history, no images, no maps (low-data requirement).
class LogisticsActiveShipmentCardWidget extends StatelessWidget {
  final LogisticsShipment shipment;

  const LogisticsActiveShipmentCardWidget({
    super.key,
    required this.shipment,
  });

  /// Stage progression across the backend lifecycle — presentation only.
  double get _stageProgress {
    final index =
        LogisticsShipmentStatus.active.indexOf(shipment.status);
    if (index < 0) return 0;
    return (index + 1) / LogisticsShipmentStatus.active.length;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final reference =
        shipment.trackingNumber ?? '#${logisticsShortId(shipment.id)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded, color: primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shipment.statusLabel.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                reference,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          Text(
            shipment.carrier == null || shipment.carrier!.isEmpty
                ? 'Carrier not assigned'
                : shipment.carrier!,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          Text(
            'Updated ${logisticsTimestamp(shipment.updatedAt)}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 16),

          LinearProgressIndicator(
            value: _stageProgress,
            color: primary,
            backgroundColor: Colors.grey.shade100,
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}
