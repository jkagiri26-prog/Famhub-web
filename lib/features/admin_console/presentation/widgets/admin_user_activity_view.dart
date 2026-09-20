/// ============================================================
/// ADMIN → USERS → USER ACTIVITY
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/widgets/ = presentation
///
/// Admin user activity feed. Data comes ONLY from the admin-safe RPC
/// `users.admin_list_user_activity` (via `adminUserActivityProvider` →
/// `AdminUserActivityService`). Search, event filter, date range and
/// pagination are server-side.
///
/// ❌ Never queries auth.audit_log_entries / auth.users / users.profiles and
///    never exposes raw audit payloads, IPs or tokens.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/application/providers/admin_capability_provider.dart';
import 'package:famhub_app/features/admin_console/application/providers/admin_user_activity_provider.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_user_activity.dart';
import 'package:famhub_app/features/admin_console/domain/permissions/permissions.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_user_list_widgets.dart';
import 'package:famhub_app/shared/widgets/cards/info_tile_widget.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

class AdminUserActivityView extends ConsumerStatefulWidget {
  const AdminUserActivityView({super.key});

  @override
  ConsumerState<AdminUserActivityView> createState() =>
      _AdminUserActivityViewState();
}

class _AdminUserActivityViewState extends ConsumerState<AdminUserActivityView> {
  static const int _pageSize = 25;

  /// Only the deployed backend event values are used.
  static const List<(String, String?)> _eventOptions = [
    ('All', null),
    ('Signups', 'user_signedup'),
    ('Confirmation Requests', 'user_confirmation_requested'),
    ('Recovery Requests', 'user_recovery_requested'),
    ('Logout', 'logout'),
  ];

  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _eventType;
  DateTime? _startDate;
  DateTime? _endDate;
  int _page = 0;

  AdminUserActivityQuery get _query => AdminUserActivityQuery(
        search: _searchController.text,
        eventType: _eventType,
        startDate: _startDate,
        endDate: _endDate,
        page: _page,
        pageSize: _pageSize,
      );

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _resetPage() {
    if (_page != 0) _page = 0;
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(_resetPage);
    });
  }

  void _setEventType(String? eventType) {
    if (_eventType == eventType) return;
    setState(() {
      _eventType = eventType;
      _page = 0;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
      _page = 0;
    });
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Existing Admin permission gating — backend RPC remains authoritative.
    final capability = ref.watch(
      adminCapabilityStatusProvider(AdminPermissions.usersView),
    );
    if (capability.isLoading) {
      return const LoadingStateWidget(message: 'Checking access...');
    }
    final access = capability.value;
    if (access == null || !access.isAllowed) {
      return PermissionDeniedWidget(
        title: 'Users access denied',
        message: access?.reason ??
            'You do not have permission to view user activity.',
      );
    }

    final pageAsync = ref.watch(adminUserActivityProvider(_query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: _toolbar(),
        ),
        Expanded(
          child: pageAsync.when(
            loading: () =>
                const LoadingStateWidget(message: 'Loading activity...'),
            error: (e, _) => ErrorStateWidget(
              title: 'Failed to load activity',
              message: 'Could not load user activity. Please try again.',
              retryLabel: 'Retry',
              onRetry: () => ref.invalidate(adminUserActivityProvider(_query)),
              detailedError: e.toString(),
            ),
            data: _buildBody,
          ),
        ),
      ],
    );
  }

  Widget _toolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search activity by user or description',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in _eventOptions)
              ChoiceChip(
                label: Text(option.$1),
                selected: _eventType == option.$2,
                onSelected: (_) => _setEventType(option.$2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickDate(isStart: true),
              icon: const Icon(Icons.event, size: 16),
              label: Text(
                _startDate == null
                    ? 'Start date'
                    : 'From ${_formatDay(_startDate!)}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(isStart: false),
              icon: const Icon(Icons.event, size: 16),
              label: Text(
                _endDate == null ? 'End date' : 'To ${_formatDay(_endDate!)}',
              ),
            ),
            if (_startDate != null || _endDate != null)
              TextButton(
                onPressed: _clearDates,
                child: const Text('Clear dates'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(AdminUserActivityPage page) {
    if (page.isEmpty) {
      final filtering = _searchController.text.trim().isNotEmpty ||
          _eventType != null ||
          _startDate != null ||
          _endDate != null;
      return EmptyStateWidget(
        icon: Icons.timeline,
        title: filtering ? 'No activity found' : 'No activity',
        subtitle: filtering
            ? 'No activity matches your search or filters.'
            : 'No user activity is available yet.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Column(
          children: [
            if (wide) const _ActivityTableHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                itemCount: page.items.length,
                itemBuilder: (_, index) {
                  final activity = page.items[index];
                  return wide
                      ? _ActivityTableRow(
                          activity: activity,
                          onTap: () => _showDetail(activity),
                        )
                      : _ActivityCard(
                          activity: activity,
                          onTap: () => _showDetail(activity),
                        );
                },
              ),
            ),
            AdminUsersPaginationFooter(
              totalCount: page.totalCount,
              itemCount: page.items.length,
              pageIndex: _page,
              pageSize: _pageSize,
              onPrev: _page > 0 ? () => setState(() => _page--) : null,
              onNext: (_page * _pageSize + page.items.length) < page.totalCount
                  ? () => setState(() => _page++)
                  : null,
            ),
          ],
        );
      },
    );
  }

  void _showDetail(AdminUserActivity activity) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _eventLabel(activity.eventType),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              InfoTileWidget(
                label: 'User',
                value: activity.displayName ?? '—',
              ),
              InfoTileWidget(
                label: 'Event',
                value: activity.eventType ?? '—',
              ),
              InfoTileWidget(
                label: 'Description',
                value: activity.description ?? '—',
              ),
              InfoTileWidget(
                label: 'Occurred',
                value: _formatDateTime(activity.occurredAt),
              ),
              InfoTileWidget(
                label: 'Profile ID',
                value: activity.profileId.isEmpty ? '—' : activity.profileId,
              ),
              // Entity / workspace / status are intentionally null for this
              // source — only shown when the backend actually returns them.
              if (activity.entityName != null || activity.entityId != null)
                InfoTileWidget(
                  label: 'Entity',
                  value: activity.entityName ?? activity.entityId!,
                ),
              if (activity.workspaceName != null ||
                  activity.workspaceId != null)
                InfoTileWidget(
                  label: 'Workspace',
                  value: activity.workspaceName ?? activity.workspaceId!,
                ),
              if (activity.status != null)
                InfoTileWidget(label: 'Status', value: activity.status!),
              const SizedBox(height: 8),
              Text(
                'Read-only view.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ROWS / CARDS
// ============================================================

class _ActivityTableHeader extends StatelessWidget {
  const _ActivityTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade600,
      letterSpacing: 0.3,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('USER', style: style)),
          Expanded(flex: 3, child: Text('ACTIVITY', style: style)),
          Expanded(flex: 5, child: Text('DESCRIPTION', style: style)),
          Expanded(flex: 3, child: Text('DATE / TIME', style: style)),
        ],
      ),
    );
  }
}

class _ActivityTableRow extends StatelessWidget {
  final AdminUserActivity activity;
  final VoidCallback onTap;

  const _ActivityTableRow({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                activity.displayName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: _EventBadge(eventType: activity.eventType),
            ),
            Expanded(
              flex: 5,
              child: Text(
                activity.description ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _formatDateTime(activity.occurredAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final AdminUserActivity activity;
  final VoidCallback onTap;

  const _ActivityCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                Expanded(
                  child: Text(
                    activity.displayName ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _EventBadge(eventType: activity.eventType),
              ],
            ),
            if (activity.description != null &&
                activity.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                activity.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(activity.occurredAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventBadge extends StatelessWidget {
  final String? eventType;

  const _EventBadge({required this.eventType});

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(eventType);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _eventLabel(eventType),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

String _eventLabel(String? eventType) {
  switch (eventType) {
    case 'user_signedup':
      return 'User signed up';
    case 'user_confirmation_requested':
      return 'Confirmation requested';
    case 'user_recovery_requested':
      return 'Recovery requested';
    case 'logout':
      return 'Logged out';
    default:
      return eventType ?? 'Activity';
  }
}

Color _eventColor(String? eventType) {
  switch (eventType) {
    case 'user_signedup':
      return Colors.green;
    case 'user_confirmation_requested':
      return Colors.blue;
    case 'user_recovery_requested':
      return Colors.orange;
    case 'logout':
      return Colors.grey;
    default:
      return Colors.blueGrey;
  }
}

String _formatDay(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatDateTime(DateTime? date) {
  if (date == null) return '—';
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
