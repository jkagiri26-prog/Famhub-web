import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/actions/action_button_row.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';

import '../../application/providers/logistics_permission_provider.dart';
import '../../config/permissions.dart';

/// Actions section — every entry point is shown only when the backend
/// grants the matching existing permission. Nothing is granted here.
class LogisticsActionsSectionWidget extends ConsumerWidget {
  /// Piece 1 wiring: the page decides what each action does.
  final VoidCallback? onBookTransport;
  final VoidCallback? onTrackShipment;

  const LogisticsActionsSectionWidget({
    super.key,
    this.onBookTransport,
    this.onTrackShipment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(
      logisticsPermissionStatusProvider(LogisticsPermissions.book),
    );
    final track = ref.watch(
      logisticsPermissionStatusProvider(LogisticsPermissions.track),
    );

    if (book.isLoading || track.isLoading) {
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
      if (book.isAllowed && onBookTransport != null)
        ActionButtonItem(
          label: 'Book Transport',
          icon: Icons.add_circle_outline_rounded,
          onPressed: onBookTransport,
          variant: ActionButtonVariant.primary,
        ),
      if (track.isAllowed && onTrackShipment != null)
        ActionButtonItem(
          label: 'Track Shipment',
          icon: Icons.pin_drop_outlined,
          onPressed: onTrackShipment,
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
