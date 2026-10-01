import 'package:flutter/material.dart';

import 'package:famhub_app/shared/widgets/cards/info_tile_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';

import '../../domain/models/logistics_dashboard_models.dart';
import '../logistics_display_utils.dart';

/// Transport section: assigned transport + pending assignments.
/// Reads are already bounded by the repository.
class LogisticsTransportSectionWidget extends StatelessWidget {
  final LogisticsDashboardSnapshot snapshot;

  const LogisticsTransportSectionWidget({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final pending = snapshot.pendingAssignments;
    final inProgress = snapshot.activeAssignments
        .where((assignment) => !assignment.isPending)
        .toList();

    if (snapshot.assignments.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeaderWidget(title: 'Transport'),
          SizedBox(height: 8),
          EmptyStateWidget(
            icon: Icons.assignment_outlined,
            title: 'No assignments yet',
            subtitle:
                'Assigned transport for your shipments will appear here '
                'once a carrier is selected.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderWidget(title: 'Transport'),
        const SizedBox(height: 8),
        Text(
          '${inProgress.length} assigned  ·  ${pending.length} pending',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),

        for (final assignment in pending)
          InfoTileWidget(
            icon: Icons.schedule_outlined,
            label:
                'Awaiting acceptance · ${logisticsTimestamp(assignment.assignedAt)}',
            value: 'Shipment #${logisticsShortId(assignment.shipmentId)}',
          ),

        for (final assignment in inProgress)
          InfoTileWidget(
            icon: Icons.local_shipping_outlined,
            label:
                '${_assignmentLabel(assignment)} · ${logisticsTimestamp(assignment.assignedAt)}',
            value: 'Shipment #${logisticsShortId(assignment.shipmentId)}',
          ),

        if (snapshot.isTruncated)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Showing the latest assignments only.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  String _assignmentLabel(LogisticsAssignment assignment) {
    switch (assignment.status) {
      case LogisticsAssignmentStatus.accepted:
        return 'Accepted';
      case LogisticsAssignmentStatus.inProgress:
        return 'In progress';
      default:
        return 'Assigned';
    }
  }
}
