/// ============================================================
/// ADMIN → USERS → ALL USERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/widgets/ = presentation
///
/// The platform-wide user directory. Data comes ONLY from the admin-safe
/// RPC `users.admin_list_users` (via `adminUsersProvider` →
/// `AdminUsersService`). Search, status filtering and pagination are
/// server-side.
///
/// ✅ Reuses: Admin permission gating, existing state widgets, existing
///    Admin section/sub-tab architecture.
/// ❌ Never queries auth.users / users.profiles / users.otp / entity_members.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/application/providers/admin_capability_provider.dart';
import 'package:famhub_app/features/admin_console/application/providers/admin_users_provider.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_user.dart';
import 'package:famhub_app/features/admin_console/domain/permissions/permissions.dart';
import 'package:famhub_app/shared/widgets/cards/info_tile_widget.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

class AdminAllUsersView extends ConsumerStatefulWidget {
  const AdminAllUsersView({super.key});

  @override
  ConsumerState<AdminAllUsersView> createState() => _AdminAllUsersViewState();
}

class _AdminAllUsersViewState extends ConsumerState<AdminAllUsersView> {
  static const int _pageSize = 25;

  static const List<(String, String?)> _statusOptions = [
    ('All', null),
    ('Active', 'active'),
    ('Inactive', 'inactive'),
    ('Pending', 'pending'),
  ];

  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _status;
  int _page = 0;

  AdminUsersQuery get _query => AdminUsersQuery(
        search: _searchController.text,
        status: _status,
        page: _page,
        pageSize: _pageSize,
      );

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _page = 0);
    });
  }

  void _setStatus(String? status) {
    if (_status == status) return;
    setState(() {
      _status = status;
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
            'You do not have permission to view the user directory.',
      );
    }

    final pageAsync = ref.watch(adminUsersProvider(_query));

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
                const LoadingStateWidget(message: 'Loading users...'),
            error: (e, _) => ErrorStateWidget(
              title: 'Failed to load users',
              message:
                  'Could not load the user directory. Please try again.',
              retryLabel: 'Retry',
              onRetry: () => ref.invalidate(adminUsersProvider(_query)),
              detailedError: e.toString(),
            ),
            data: _buildList,
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
            hintText: 'Search users by name, email or phone',
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
            for (final option in _statusOptions)
              ChoiceChip(
                label: Text(option.$1),
                selected: _status == option.$2,
                onSelected: (_) => _setStatus(option.$2),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildList(AdminUsersPage page) {
    if (page.isEmpty) {
      final filtering =
          _searchController.text.trim().isNotEmpty || _status != null;
      return EmptyStateWidget(
        icon: Icons.people_outline,
        title: filtering ? 'No users found' : 'No users',
        subtitle: filtering
            ? 'No users match your search or filter.'
            : 'No users are available in the directory yet.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Column(
          children: [
            if (wide) _tableHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                itemCount: page.items.length,
                itemBuilder: (_, index) {
                  final user = page.items[index];
                  return wide
                      ? _UserTableRow(
                          user: user,
                          onTap: () => _openDetail(user),
                        )
                      : _UserCard(
                          user: user,
                          onTap: () => _openDetail(user),
                        );
                },
              ),
            ),
            _paginationFooter(page),
          ],
        );
      },
    );
  }

  Widget _tableHeader() {
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
          Expanded(flex: 4, child: Text('CONTACT', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(flex: 2, child: Text('WORKSPACES', style: style)),
          Expanded(flex: 2, child: Text('ENTITIES', style: style)),
          Expanded(flex: 2, child: Text('JOINED', style: style)),
        ],
      ),
    );
  }

  Widget _paginationFooter(AdminUsersPage page) {
    final start = page.totalCount == 0 ? 0 : _query.offset + 1;
    final end = _query.offset + page.items.length;
    final hasPrev = _page > 0;
    final hasNext = end < page.totalCount;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $start–$end of ${page.totalCount}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          IconButton(
            tooltip: 'Previous',
            onPressed: hasPrev ? () => setState(() => _page--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Page ${_page + 1}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: hasNext ? () => setState(() => _page++) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _openDetail(AdminUser user) {
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
                user.displayName.isEmpty ? 'User' : user.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              InfoTileWidget(label: 'Email', value: user.email ?? '—'),
              InfoTileWidget(label: 'Phone', value: user.phone ?? '—'),
              InfoTileWidget(
                label: 'Account status',
                value: user.accountStatus ?? (user.isActive ? 'active' : '—'),
              ),
              InfoTileWidget(
                label: 'Profile status',
                value: user.profileStatus ?? '—',
              ),
              InfoTileWidget(
                label: 'Onboarding',
                value: user.isComplete ? 'Complete' : 'Pending',
              ),
              InfoTileWidget(
                label: 'Verified',
                value: user.verified ? 'Yes' : 'No',
              ),
              InfoTileWidget(
                label: 'Workspaces',
                value: '${user.workspaceCount}',
              ),
              InfoTileWidget(
                label: 'Default workspace',
                value: user.defaultWorkspaceName ??
                    user.defaultWorkspaceId ??
                    '—',
              ),
              InfoTileWidget(
                label: 'Entities',
                value: '${user.entityCount}',
              ),
              InfoTileWidget(
                label: 'Joined',
                value: _formatDate(user.createdAt),
              ),
              const SizedBox(height: 8),
              Text(
                'Read-only view. Management actions are not available yet.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

// ============================================================
// ROWS / CARDS
// ============================================================

class _UserTableRow extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;

  const _UserTableRow({required this.user, required this.onTap});

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
                user.displayName.isEmpty ? '—' : user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                _contact(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            Expanded(flex: 2, child: _StatusBadge(user: user)),
            Expanded(
              flex: 2,
              child: Text('${user.workspaceCount}',
                  style: const TextStyle(fontSize: 12)),
            ),
            Expanded(
              flex: 2,
              child: Text('${user.entityCount}',
                  style: const TextStyle(fontSize: 12)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _shortDate(user.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;

  const _UserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.displayName);
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.displayName.isEmpty ? '—' : user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(user: user),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _contact(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _MiniStat(
                        icon: Icons.workspaces_outline,
                        label: '${user.workspaceCount} workspaces',
                      ),
                      _MiniStat(
                        icon: Icons.business_outlined,
                        label: '${user.entityCount} entities',
                      ),
                      _MiniStat(
                        icon: user.isComplete
                            ? Icons.check_circle_outline
                            : Icons.hourglass_empty,
                        label: user.isComplete ? 'Onboarded' : 'Pending',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AdminUser user;

  const _StatusBadge({required this.user});

  @override
  Widget build(BuildContext context) {
    final account = (user.accountStatus ?? '').toLowerCase();
    Color color;
    if (account == 'active') {
      color = Colors.green;
    } else if (account == 'suspended' || account == 'blocked') {
      color = Colors.red;
    } else {
      color = user.isActive ? Colors.green : Colors.grey;
    }
    final label = user.accountStatus?.isNotEmpty == true
        ? _titleCase(user.accountStatus!)
        : (user.isActive ? 'Active' : 'Inactive');

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

String _contact(AdminUser user) {
  if (user.email != null && user.email!.isNotEmpty) return user.email!;
  if (user.phone != null && user.phone!.isNotEmpty) return user.phone!;
  return '—';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

String _shortDate(DateTime? date) {
  if (date == null) return '—';
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
