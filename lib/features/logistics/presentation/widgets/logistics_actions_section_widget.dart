import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/actions/action_button_row.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';

import '../../application/providers/logistics_permission_provider.dart';
import '../../config/permissions.dart';

/// Actions section — every entry point is shown only when the backend
/// grants the matching permission. Nothing is granted here.
class LogisticsActionsSectionWidget extends ConsumerWidget {
  final VoidCallback? onViewShipments;
  final VoidCallback? onAssignTransport;
  final VoidCallback? onViewTracking;

  const LogisticsActionsSectionWidget({
    super.key,
    this.onViewShipments,
    this.onAssignTransport,
    this.onViewTracking,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewShipments = ref.watch(
      logisticsPermissionStatusProvider(LogisticsPermissions.viewShipments),
    );
    final assignTransport = ref.watch(
      logisticsPermissionStatusProvider(LogisticsPermissions.assignTransport),
    );
    final viewTracking = ref.watch(
      logisticsPermissionStatusProvider(LogisticsPermissions.viewLiveTracking),
    );

    if (viewShipments.isLoading ||
        assignTransport.isLoading ||
        viewTracking.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeaderWidget(title: 'Actions'),
          SizedBox(height: 8),
          Text(
            'Checking available actions...',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      );
    }

    final actions = <ActionButtonItem>[
      if (viewShipments.isAllowed && onViewShipments != null)
        ActionButtonItem(
          label: 'Shipments',
          icon: Icons.local_shipping_outlined,
          onPressed: onViewShipments,
          variant: ActionButtonVariant.primary,
        ),
      if (assignTransport.isAllowed && onAssignTransport != null)
        ActionButtonItem(
          label: 'Assign transport',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: onAssignTransport,
          variant: ActionButtonVariant.secondary,
        ),
      if (viewTracking.isAllowed && onViewTracking != null)
        ActionButtonItem(
          label: 'Live tracking',
          icon: Icons.pin_drop_outlined,
          onPressed: onViewTracking,
          variant: ActionButtonVariant.secondary,
        ),
    ];

    if (actions.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeaderWidget(title: 'Actions'),
          SizedBox(height: 8),
          EmptyStateWidget(
            icon: Icons.lock_outline,
            title: 'No actions available',
            subtitle:
                'Actions appear here once the backend grants the matching '
                'Logistics permission for your role.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderWidget(title: 'Actions'),
        const SizedBox(height: 12),
        ActionButtonRow(actions: actions),
      ],
    );
  }
}
