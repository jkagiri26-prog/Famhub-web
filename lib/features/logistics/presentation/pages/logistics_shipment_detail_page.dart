import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/permission_denied_widget.dart';

import '../../application/providers/logistics_driver_tracking_provider.dart';
import '../../application/providers/logistics_permission_provider.dart';
import '../../application/providers/logistics_shipment_provider.dart';
import '../../config/permissions.dart';
import '../../domain/models/logistics_dashboard_models.dart';
import '../../domain/models/logistics_detail_models.dart';
import '../logistics_display_utils.dart';
import '../widgets/logistics_assign_transport_dialog.dart';
import '../widgets/logistics_driver_tracking_controls_widget.dart';

/// ============================================================
/// LOGISTICS — SHIPMENT DETAIL PAGE
/// ============================================================
///
/// One bounded payload for a single shipment: overview, items, stops,
/// transport assignments, tracking session controls and recent events.
///
/// Architecture compliance:
/// - No Scaffold / AppBar / Drawer (shell owns them)
/// - ResponsiveWrapper enforced
/// - Transport assignment and tracking controls are backend-permission
///   gated; the backend stays authoritative for every action
/// - Loading / empty / error / permission states are always rendered
/// ============================================================
class LogisticsShipmentDetailPage extends ConsumerWidget {
  final String shipmentId;

  const LogisticsShipmentDetailPage({
    super.key,
    required this.shipmentId,
  });

  static Route<void> route({required String shipmentId}) {
    return MaterialPageRoute<void>(
      builder: (_) => LogisticsShipmentDetailPage(shipmentId: shipmentId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entityContext = ref.watch(contextProvider);

    if (entityContext.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Preparing your shipment...'),
      );
    }

    if (entityContext.isGuest) {
      return const ResponsiveWrapper(
        child: PermissionDeniedWidget(
          title: 'Shipment locked',
          message: 'Sign in to view this shipment.',
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
              ? 'Shipment unavailable'
              : 'Shipment locked',
          message: permission.reason ??
              'Shipment access is not enabled for your role.',
        ),
      );
    }

    final detail = ref.watch(logisticsShipmentDetailProvider(shipmentId));

    return ResponsiveWrapper(
      child: detail.when(
        loading: () =>
            const LoadingStateWidget(message: 'Loading shipment...'),
        error: (error, stackTrace) => ErrorStateWidget(
          title: 'Failed to Load',
          message: 'Could not load this shipment.',
          retryLabel: 'Retry',
          onRetry: () =>
              ref.invalidate(logisticsShipmentDetailProvider(shipmentId)),
          detailedError: error.toString(),
        ),
        data: (payload) {
          if (payload == null) {
            return ListView(
              physics: const BouncingScrollPhysics(),
              children: const [
                SizedBox(height: 10),
                _BackBar(),
                SizedBox(height: 8),
                ModuleHeaderWidget(
                  title: 'Shipment',
                  subtitle: 'Reference, status and route',
                ),
                SizedBox(height: 16),
                EmptyStateWidget(
                  icon: Icons.search_off_outlined,
                  title: 'Shipment not available',
                  subtitle:
                      'This shipment could not be found, or it is not '
                      'accessible for the active context.',
                ),
              ],
            );
          }

          return _ShipmentDetailContent(
            shipmentId: shipmentId,
            detail: payload,
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

class _ShipmentDetailContent extends ConsumerWidget {
  final String shipmentId;
  final LogisticsShipmentDetail detail;

  const _ShipmentDetailContent({
    required this.shipmentId,
    required this.detail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipment = detail.shipment;
    final reference =
        shipment.trackingNumber ?? '#${logisticsShortId(shipment.id)}';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 10),
        const _BackBar(),
        const SizedBox(height: 8),

        ModuleHeaderWidget(
          title: reference,
          subtitle: shipment.statusLabel,
          trailingIcon: Icons.refresh_rounded,
          onTrailingTap: () =>
              ref.invalidate(logisticsShipmentDetailProvider(shipmentId)),
        ),
        const SizedBox(height: 16),

        _OverviewCard(detail: detail),
        const SizedBox(height: 24),

        if (detail.items.isNotEmpty) ...[
          const SectionHeaderWidget(title: 'Items'),
          const SizedBox(height: 8),
          for (final item in detail.items) _ItemRow(item: item),
          const SizedBox(height: 8),
        ],

        if (detail.stops.isNotEmpty) ...[
          const SectionHeaderWidget(title: 'Route'),
          const SizedBox(height: 8),
          for (final stop in detail.stops) _StopRow(stop: stop),
          const SizedBox(height: 8),
        ],

        const SectionHeaderWidget(title: 'Transport'),
        const SizedBox(height: 8),
        _TransportSection(detail: detail, shipmentId: shipmentId),
        const SizedBox(height: 24),

        const SectionHeaderWidget(title: 'Tracking'),
        const SizedBox(height: 8),
        _TrackingSection(
          target: _resolveTrackingTarget(detail, shipmentId),
          hasTransport: detail.assignments.isNotEmpty,
        ),
        const SizedBox(height: 24),

        if (detail.events.isNotEmpty) ...[
          const SectionHeaderWidget(title: 'Recent events'),
          const SizedBox(height: 8),
          for (final event in detail.events) _EventRow(event: event),
        ],

        if (detail.isTruncated)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing the most recent records only.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  /// Controls are attached to the assignment the driver can act on: an
  /// active assignment, or any assignment that already has a session.
  static DriverTrackingTarget? _resolveTrackingTarget(
    LogisticsShipmentDetail detail,
    String shipmentId,
  ) {
    for (final assignment in detail.assignments) {
      if (assignment.isTrackable ||
          detail.sessionForAssignment(assignment.id) != null) {
        return DriverTrackingTarget(
          assignmentId: assignment.id,
          shipmentId: shipmentId,
        );
      }
    }
    return null;
  }
}

// ── Overview ───────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final LogisticsShipmentDetail detail;

  const _OverviewCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final shipment = detail.shipment;
    final origin = detail.originStop;
    final destination = detail.destinationStop;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_shipping_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shipment.statusLabel.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                shipment.trackingNumber ?? '—',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _kv('Carrier', shipment.carrier ?? 'Carrier not assigned'),
          _kv('Updated', logisticsTimestamp(shipment.updatedAt)),
          if (origin != null) _kv('Origin', '${origin.stopTypeLabel} · ${origin.locationLabel}'),
          if (destination != null)
            _kv('Destination',
                '${destination.stopTypeLabel} · ${destination.locationLabel}'),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              key,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Items ──────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final LogisticsShipmentItem item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.notes!.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.quantityLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (item.packageLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              item.packageLabel,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stops ──────────────────────────────────────────────────────

class _StopRow extends StatelessWidget {
  final LogisticsStop stop;

  const _StopRow({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            stop.isPickup
                ? Icons.trip_origin_outlined
                : stop.isDropoff
                    ? Icons.flag_outlined
                    : Icons.swap_horiz_outlined,
            size: 18,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stop.sequenceNumber}. ${stop.stopTypeLabel} · '
                  '${stop.locationLabel}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scheduled ${logisticsTimestamp(stop.scheduledArrival)}'
                  '${stop.actualArrival != null ? ' · Arrived ${logisticsTimestamp(stop.actualArrival)}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            stop.statusLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transport ──────────────────────────────────────────────────

class _TransportSection extends ConsumerWidget {
  final LogisticsShipmentDetail detail;
  final String shipmentId;

  const _TransportSection({
    required this.detail,
    required this.shipmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignPermission = ref.watch(
      logisticsPermissionStatusProvider(LogisticsPermissions.assignTransport),
    );

    final assignAction = assignPermission.isLoading || !assignPermission.isAllowed
        ? null
        : () async {
            final assigned = await LogisticsAssignTransportDialog.show(
              context,
              shipmentId: shipmentId,
            );
            if (assigned && context.mounted) {
              ref.invalidate(
                logisticsShipmentDetailProvider(shipmentId),
              );
            }
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.assignments.isEmpty)
          EmptyStateWidget(
            icon: Icons.person_add_alt_outlined,
            title: 'No transport assigned',
            subtitle: assignAction == null
                ? 'Assigning transport is not enabled for your role.'
                : 'Assign a carrier to move this shipment.',
            actionLabel: assignAction == null ? null : 'Assign transport',
            onAction: assignAction,
          )
        else ...[
          for (final assignment in detail.assignments)
            _AssignmentRow(assignment: assignment),
          if (assignAction != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: assignAction,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Assign another carrier'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final LogisticsAssignment assignment;

  const _AssignmentRow({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  assignment.providerName ??
                      'Provider ${logisticsShortId(assignment.providerEntityId ?? '')}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _statusLabel(assignment.status),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (assignment.driverName != null ||
              assignment.vehicleLabel != null)
            Text(
              [
                if (assignment.driverName != null) assignment.driverName!,
                if (assignment.vehicleLabel != null)
                  assignment.vehicleLabel!,
              ].join(' · '),
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          Text(
            'Assigned ${logisticsTimestamp(assignment.assignedAt)}'
            '${assignment.acceptedAt != null ? ' · Accepted ${logisticsTimestamp(assignment.acceptedAt)}' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (assignment.notes != null &&
              assignment.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              assignment.notes!.trim(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      case 'reassigned':
        return 'Reassigned';
      default:
        return 'Assigned';
    }
  }
}

// ── Tracking ───────────────────────────────────────────────────

class _TrackingSection extends StatelessWidget {
  final DriverTrackingTarget? target;
  final bool hasTransport;

  const _TrackingSection({required this.target, required this.hasTransport});

  @override
  Widget build(BuildContext context) {
    if (target != null) {
      return LogisticsDriverTrackingControlsWidget(target: target!);
    }

    return EmptyStateWidget(
      icon: Icons.gps_off_outlined,
      title: 'Tracking not started',
      subtitle: hasTransport
          ? 'Tracking controls appear once a shipment is assigned to an '
              'active carrier.'
          : 'Assign transport to this shipment before starting tracking.',
    );
  }
}

// ── Events ─────────────────────────────────────────────────────

class _EventRow extends StatelessWidget {
  final LogisticsTrackingEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.timeline_outlined, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.eventTypeLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            logisticsTimestamp(event.occurredAt),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
