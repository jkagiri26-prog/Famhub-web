import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/actions/action_button_row.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

import '../../application/providers/logistics_driver_tracking_provider.dart';
import '../../application/providers/logistics_permission_provider.dart';
import '../../config/permissions.dart';
import '../../domain/models/logistics_dashboard_models.dart';
import '../logistics_display_utils.dart';

/// Driver tracking controls for a single transport assignment.
///
/// - Every lifecycle control maps to a confirmed backend RPC.
/// - Controls are disabled while an RPC is in flight.
/// - Completed / cancelled sessions expose no lifecycle controls at all.
/// - Device location permission is only requested from an explicit
///   Start / Resume / Start-recording tap — never on page load.
class LogisticsDriverTrackingControlsWidget extends ConsumerWidget {
  final DriverTrackingTarget target;

  const LogisticsDriverTrackingControlsWidget({
    super.key,
    required this.target,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateTracking = ref.watch(
      logisticsPermissionStatusProvider(LogisticsPermissions.updateTracking),
    );
    final recordLocation = ref.watch(
      logisticsPermissionStatusProvider(LogisticsPermissions.recordLocation),
    );

    if (updateTracking.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeaderWidget(title: 'Tracking session'),
          SizedBox(height: 8),
          LoadingStateWidget(message: 'Checking tracking access...'),
        ],
      );
    }

    if (!updateTracking.isAllowed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeaderWidget(title: 'Tracking session'),
          const SizedBox(height: 8),
          EmptyStateWidget(
            icon: updateTracking.isUnavailable
                ? Icons.cloud_off_outlined
                : Icons.lock_outline,
            title: updateTracking.isUnavailable
                ? 'Tracking unavailable'
                : 'Tracking locked',
            subtitle: updateTracking.reason ??
                'Tracking controls are not enabled for your role.',
          ),
        ],
      );
    }

    final state = ref.watch(driverTrackingControllerProvider(target));
    final controller = ref.read(driverTrackingControllerProvider(target).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderWidget(title: 'Tracking session'),
        const SizedBox(height: 10),

        _StatusRow(state: state),
        const SizedBox(height: 10),

        if (state.lastError != null) ...[
          _MessageBanner(
            message: state.lastError!,
            isError: true,
          ),
          const SizedBox(height: 10),
        ],

        if (state.isLoading)
          const LoadingStateWidget(message: 'Loading tracking session...')
        else ...[
          _LifecycleButtons(
            state: state,
            onStart: controller.start,
            onPause: controller.pause,
            onResume: controller.resume,
            onComplete: controller.complete,
          ),

          if (state.sessionStatus == LogisticsTrackingStatus.active) ...[
            const SizedBox(height: 8),
            _RecordingToggle(
              state: state,
              recordLocationAllowed: recordLocation.isAllowed,
              onStartRecording: controller.startRecording,
              onStopRecording: controller.stopRecording,
            ),
          ],

          if (state.isTerminalSession) ...[
            const SizedBox(height: 8),
            Text(
              'This tracking session has ended. No further tracking '
              'actions are available.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],

          if (state.queuedCount > 0) ...[
            const SizedBox(height: 8),
            ActionButtonRow(
              actions: [
                ActionButtonItem(
                  label: 'Retry ${state.queuedCount} saved point'
                      '${state.queuedCount == 1 ? '' : 's'}',
                  icon: Icons.cloud_sync_outlined,
                  variant: ActionButtonVariant.tertiary,
                  onPressed:
                      state.canRetryQueue ? controller.retryQueued : null,
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final DriverTrackingState state;

  const _StatusRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            state.sessionStatusLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        if (state.isRecording)
          const _DotBadge(label: 'GPS on', color: Colors.green),
        if (state.sentCount > 0)
          _DotBadge(label: '${state.sentCount} sent', color: Colors.blueGrey),
        if (state.queuedCount > 0)
          _DotBadge(label: '${state.queuedCount} queued', color: Colors.orange),
        if (state.lastSentAt != null)
          Text(
            'Last ping ${logisticsTimestamp(state.lastSentAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
      ],
    );
  }
}

class _DotBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DotBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red.shade700 : Colors.black87;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? Colors.red.shade100 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecycleButtons extends StatelessWidget {
  final DriverTrackingState state;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;

  const _LifecycleButtons({
    required this.state,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <ActionButtonItem>[];

    switch (state.sessionStatus) {
      case null:
        actions.add(
          ActionButtonItem(
            label: state.isBusy ? 'Working...' : 'Start tracking',
            icon: Icons.play_arrow_rounded,
            variant: ActionButtonVariant.primary,
            onPressed: state.canStartSession ? onStart : null,
          ),
        );
        break;
      case LogisticsTrackingStatus.active:
        actions.add(
          ActionButtonItem(
            label: 'Pause',
            icon: Icons.pause_rounded,
            variant: ActionButtonVariant.secondary,
            onPressed: state.canPauseSession ? onPause : null,
          ),
        );
        actions.add(
          ActionButtonItem(
            label: state.isBusy ? 'Completing...' : 'Complete',
            icon: Icons.check_circle_outline_rounded,
            variant: ActionButtonVariant.primary,
            onPressed: state.canCompleteSession ? onComplete : null,
          ),
        );
        break;
      case LogisticsTrackingStatus.paused:
        actions.add(
          ActionButtonItem(
            label: 'Resume',
            icon: Icons.play_circle_outline_rounded,
            variant: ActionButtonVariant.primary,
            onPressed: state.canResumeSession ? onResume : null,
          ),
        );
        actions.add(
          ActionButtonItem(
            label: state.isBusy ? 'Completing...' : 'Complete',
            icon: Icons.check_circle_outline_rounded,
            variant: ActionButtonVariant.primary,
            onPressed: state.canCompleteSession ? onComplete : null,
          ),
        );
        break;
      default:
        // Completed / cancelled sessions expose no lifecycle controls.
        break;
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return ActionButtonRow(actions: actions);
  }
}

class _RecordingToggle extends StatelessWidget {
  final DriverTrackingState state;
  final bool recordLocationAllowed;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  const _RecordingToggle({
    required this.state,
    required this.recordLocationAllowed,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  @override
  Widget build(BuildContext context) {
    if (!recordLocationAllowed) {
      return Text(
        'Location recording is not enabled for your role.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );
    }

    final recording = state.isRecording;
    return ActionButtonRow(
      actions: [
        ActionButtonItem(
          label: recording ? 'Stop recording' : 'Start recording',
          icon: recording
              ? Icons.gps_not_fixed
              : Icons.gps_fixed_outlined,
          variant: ActionButtonVariant.secondary,
          onPressed: !state.canToggleRecording
              ? null
              : recording
                  ? onStopRecording
                  : onStartRecording,
        ),
      ],
    );
  }
}
