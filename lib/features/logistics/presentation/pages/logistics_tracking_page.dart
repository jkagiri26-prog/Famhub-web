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

import '../../application/providers/logistics_permission_provider.dart';
import '../../application/providers/logistics_tracking_provider.dart';
import '../../config/permissions.dart';
import '../../domain/models/logistics_dashboard_models.dart';
import '../../domain/models/logistics_detail_models.dart';
import '../logistics_display_utils.dart';

/// ============================================================
/// LOGISTICS — LIVE / RECENT TRACKING PAGE
/// ============================================================
///
/// Bounded, explicitly refreshed tracking history.
///
/// Architecture compliance:
/// - No Scaffold / AppBar / Drawer (shell owns them)
/// - ResponsiveWrapper enforced
/// - Refresh only on explicit user action — no polling, no map SDK,
///   no background location
/// - Reads only: GPS writes live in the driver tracking controller
/// ============================================================
class LogisticsTrackingPage extends ConsumerWidget {
  final String? trackingSessionId;

  const LogisticsTrackingPage({super.key, this.trackingSessionId});

  static Route<void> route({String? trackingSessionId}) {
    return MaterialPageRoute<void>(
      builder: (_) => LogisticsTrackingPage(
        trackingSessionId: trackingSessionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entityContext = ref.watch(contextProvider);

    if (entityContext.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Preparing live tracking...'),
      );
    }

    if (entityContext.isGuest) {
      return const ResponsiveWrapper(
        child: PermissionDeniedWidget(
          title: 'Tracking locked',
          message: 'Sign in to view live tracking for your active entity.',
        ),
      );
    }

    final permission = ref.watch(
      logisticsPermissionStatusProvider(LogisticsPermissions.viewLiveTracking),
    );

    if (permission.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Checking tracking access...'),
      );
    }

    if (!permission.isAllowed) {
      return ResponsiveWrapper(
        child: PermissionDeniedWidget(
          title: permission.isUnavailable
              ? 'Tracking unavailable'
              : 'Tracking locked',
          message: permission.reason ??
              'Live tracking is not enabled for your role.',
        ),
      );
    }

    final sessionId = trackingSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return const ResponsiveWrapper(child: _SessionPicker());
    }

    return ResponsiveWrapper(child: _SessionHistory(trackingSessionId: sessionId));
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

// ── Session picker ─────────────────────────────────────────────

class _SessionPicker extends ConsumerWidget {
  const _SessionPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(logisticsTrackingSessionsProvider);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 10),
        const _BackBar(),
        const SizedBox(height: 8),
        ModuleHeaderWidget(
          title: 'Live tracking',
          subtitle: 'Recent tracking sessions · explicit refresh only',
          trailingIcon: Icons.refresh_rounded,
          onTrailingTap: () => ref.invalidate(logisticsTrackingSessionsProvider),
        ),
        const SizedBox(height: 16),
        sessions.when(
          loading: () =>
              const LoadingStateWidget(message: 'Loading tracking sessions...'),
          error: (error, stackTrace) => ErrorStateWidget(
            title: 'Failed to Load',
            message: 'Could not load tracking sessions.',
            retryLabel: 'Retry',
            onRetry: () => ref.invalidate(logisticsTrackingSessionsProvider),
            detailedError: error.toString(),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.gps_off_outlined,
                title: 'No tracking sessions',
                subtitle:
                    'Tracking sessions appear here once an assigned driver '
                    'starts recording a shipment.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeaderWidget(title: 'Recent sessions'),
                const SizedBox(height: 8),
                for (final session in rows)
                  _SessionTile(
                    session: session,
                    onTap: () => Navigator.of(context).push(
                      LogisticsTrackingPage.route(
                        trackingSessionId: session.id,
                      ),
                    ),
                  ),
                Text(
                  'Showing the ${rows.length} most recent session'
                      '${rows.length == 1 ? '' : 's'} only.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final LogisticsTrackingSession session;
  final VoidCallback onTap;

  const _SessionTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
              session.isActive
                  ? Icons.gps_fixed
                  : session.isTerminal
                      ? Icons.gps_off_outlined
                      : Icons.gps_not_fixed_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shipment #${logisticsShortId(session.shipmentId)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.isTerminal
                        ? 'Session ${session.status}'
                        : 'Last ping '
                            '${logisticsTimestamp(session.lastLocationCapturedAt)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade500,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session history ────────────────────────────────────────────

class _SessionHistory extends ConsumerWidget {
  final String trackingSessionId;

  const _SessionHistory({required this.trackingSessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      logisticsTrackingSessionDetailProvider(trackingSessionId),
    );

    return detail.when(
      loading: () => const LoadingStateWidget(
        message: 'Loading tracking history...',
      ),
      error: (error, stackTrace) => ErrorStateWidget(
        title: 'Failed to Load',
        message: 'Could not load the tracking history.',
        retryLabel: 'Retry',
        onRetry: () => ref.invalidate(
          logisticsTrackingSessionDetailProvider(trackingSessionId),
        ),
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
                title: 'Live tracking',
                subtitle: 'Location history for this session',
              ),
              SizedBox(height: 16),
              EmptyStateWidget(
                icon: Icons.search_off_outlined,
                title: 'Session not available',
                subtitle:
                    'This tracking session could not be found, or it is not '
                    'accessible for the active context.',
              ),
            ],
          );
        }

        final session = payload.session;
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const SizedBox(height: 10),
            const _BackBar(),
            const SizedBox(height: 8),
            ModuleHeaderWidget(
              title: 'Shipment #${logisticsShortId(session.shipmentId)}',
              subtitle: 'Session ${session.status} · ${payload.points.length} '
                  'point${payload.points.length == 1 ? '' : 's'} loaded',
              trailingIcon: Icons.refresh_rounded,
              onTrailingTap: () => ref.invalidate(
                logisticsTrackingSessionDetailProvider(trackingSessionId),
              ),
            ),
            const SizedBox(height: 16),

            _SessionSummary(payload: payload),
            const SizedBox(height: 24),

            const SectionHeaderWidget(title: 'Location history'),
            const SizedBox(height: 8),

            if (payload.points.isEmpty)
              const EmptyStateWidget(
                icon: Icons.location_off_outlined,
                title: 'No location points yet',
                subtitle:
                    'Points appear here as soon as the assigned driver '
                    'records them while a session is active.',
              )
            else ...[
              for (final point in payload.points) _PointRow(point: point),
              Text(
                payload.isTruncated
                    ? 'Showing the most recent ${payload.points.length} '
                        'points only.'
                    : 'Showing all ${payload.points.length} recorded points.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SessionSummary extends StatelessWidget {
  final LogisticsTrackingSessionDetail payload;

  const _SessionSummary({required this.payload});

  @override
  Widget build(BuildContext context) {
    final session = payload.session;

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
                session.isActive
                    ? Icons.gps_fixed
                    : session.isTerminal
                        ? Icons.gps_off_outlined
                        : Icons.gps_not_fixed_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.status.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _kv('Started', logisticsTimestamp(session.startedAt)),
          _kv('Ended', logisticsTimestamp(session.endedAt)),
          _kv(
            'Last ping',
            logisticsTimestamp(
              payload.latestCapturedAt ?? session.lastLocationCapturedAt,
            ),
          ),
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

class _PointRow extends StatelessWidget {
  final LogisticsLocationPoint point;

  const _PointRow({required this.point});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined,
              size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.coordinatesLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (point.accuracy != null)
                      '±${point.accuracy!.toStringAsFixed(0)} m',
                    if (point.speed != null)
                      '${point.speed!.toStringAsFixed(1)} m/s',
                    if (point.heading != null)
                      '${point.heading!.toStringAsFixed(0)}°',
                  ].join('  · '),
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
            logisticsTimestamp(point.capturedAt),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
