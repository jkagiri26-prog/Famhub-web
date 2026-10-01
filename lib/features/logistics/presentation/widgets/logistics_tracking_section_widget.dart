import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/cards/info_tile_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

import '../../application/providers/logistics_permission_provider.dart';
import '../../config/permissions.dart';
import '../../domain/models/logistics_dashboard_models.dart';
import '../logistics_display_utils.dart';

/// Tracking section — the future home of GPS capture.
///
/// Piece 1 only *reads* bounded tracking-session metadata through the
/// existing backend. It does NOT request device location permission,
/// start background location, or load maps.
///
/// Visibility is gated by the existing backend permission
/// `logistics.view_live_tracking`. `logistics.record_location` is
/// intentionally not used here — driver capture arrives later and must
/// honour the backend contract that only the assigned driver may post
/// location points.
class LogisticsTrackingSectionWidget extends ConsumerWidget {
  final LogisticsDashboardSnapshot snapshot;

  const LogisticsTrackingSectionWidget({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      logisticsPermissionStatusProvider(
        LogisticsPermissions.viewLiveTracking,
      ),
    );

    if (status.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeaderWidget(title: 'Tracking'),
          SizedBox(height: 8),
          LoadingStateWidget(message: 'Checking tracking access...'),
        ],
      );
    }

    if (!status.isAllowed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeaderWidget(title: 'Tracking'),
          const SizedBox(height: 8),
          EmptyStateWidget(
            icon: status.isUnavailable
                ? Icons.cloud_off_outlined
                : Icons.lock_outline,
            title: status.isUnavailable
                ? 'Tracking unavailable'
                : 'Tracking locked',
            subtitle: status.reason ??
                'Live tracking is not enabled for your role.',
          ),
        ],
      );
    }

    final sessions = snapshot.activeTrackingSessions;
    final latest = snapshot.latestTrackingCapture;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderWidget(title: 'Tracking'),
        const SizedBox(height: 8),

        if (sessions.isEmpty)
          snapshot.trackingAvailable
              ? const EmptyStateWidget(
                  icon: Icons.gps_fixed_outlined,
                  title: 'Tracking available',
                  subtitle:
                      'No active tracking session right now. A session '
                      'starts once the assigned driver begins recording.',
                )
              : const EmptyStateWidget(
                  icon: Icons.gps_off_outlined,
                  title: 'No active tracking',
                  subtitle:
                      'Tracking sessions will appear here once a shipment '
                      'is assigned.',
                )
        else ...[
          if (latest != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Last location received ${logisticsTimestamp(latest)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          for (final session in sessions)
            InfoTileWidget(
              icon: Icons.location_on_outlined,
              label: session.lastLocationCapturedAt == null
                  ? 'Started ${logisticsTimestamp(session.startedAt)}'
                  : 'Last ping '
                      '${logisticsTimestamp(session.lastLocationCapturedAt)}',
              value: 'Shipment #${logisticsShortId(session.shipmentId)}',
            ),
        ],
      ],
    );
  }
}
