/// ============================================================
/// ADMIN USER LIST — SHARED PRESENTATION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/widgets/ = presentation
///
/// Reusable presentation for admin user directories (All Users,
/// Pending / Onboarding, ...). Pure UI — no providers, no backend access.
///
/// Data is always the admin-safe projection from `users.admin_list_users`.
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'package:famhub_app/features/admin_console/domain/models/admin_user.dart';
import 'package:famhub_app/shared/widgets/cards/info_tile_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';

// ============================================================
// HELPERS
// ============================================================

String adminUserContact(AdminUser user) {
  if (user.email != null && user.email!.isNotEmpty) return user.email!;
  if (user.phone != null && user.phone!.isNotEmpty) return user.phone!;
  return '—';
}

String adminUserInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String adminUserShortDate(DateTime? date) {
  if (date == null) return '—';
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

// ============================================================
// WIDGETS
// ============================================================

class AdminUserStatusBadge extends StatelessWidget {
  final AdminUser user;

  const AdminUserStatusBadge({super.key, required this.user});

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

class AdminUserTableHeader extends StatelessWidget {
  const AdminUserTableHeader({super.key});

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
          Expanded(flex: 4, child: Text('CONTACT', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(flex: 2, child: Text('WORKSPACES', style: style)),
          Expanded(flex: 2, child: Text('ENTITIES', style: style)),
          Expanded(flex: 2, child: Text('JOINED', style: style)),
        ],
      ),
    );
  }
}

class AdminUserTableRow extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;

  const AdminUserTableRow({
    super.key,
    required this.user,
    required this.onTap,
  });

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
                adminUserContact(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            Expanded(flex: 2, child: AdminUserStatusBadge(user: user)),
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
                adminUserShortDate(user.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminUserCard extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;

  const AdminUserCard({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = adminUserInitials(user.displayName);
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
                      AdminUserStatusBadge(user: user),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    adminUserContact(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      AdminUserMiniStat(
                        icon: Icons.workspaces_outline,
                        label: '${user.workspaceCount} workspaces',
                      ),
                      AdminUserMiniStat(
                        icon: Icons.business_outlined,
                        label: '${user.entityCount} entities',
                      ),
                      AdminUserMiniStat(
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

class AdminUserMiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const AdminUserMiniStat({super.key, required this.icon, required this.label});

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

class AdminUsersPaginationFooter extends StatelessWidget {
  final int totalCount;
  final int itemCount;
  final int pageIndex;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const AdminUsersPaginationFooter({
    super.key,
    required this.totalCount,
    required this.itemCount,
    required this.pageIndex,
    required this.pageSize,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final offset = pageIndex * pageSize;
    final start = totalCount == 0 ? 0 : offset + 1;
    final end = offset + itemCount;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $start–$end of $totalCount',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          IconButton(
            tooltip: 'Previous',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Page ${pageIndex + 1}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// Responsive directory body shared by the admin user directories
/// (table on wide screens, compact cards on narrow screens) with the
/// empty state and pagination footer.
class AdminUsersDirectoryBody extends StatelessWidget {
  final AdminUsersPage page;
  final int pageIndex;
  final int pageSize;
  final String emptyTitle;
  final String emptySubtitle;
  final bool filtering;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const AdminUsersDirectoryBody({
    super.key,
    required this.page,
    required this.pageIndex,
    required this.pageSize,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.filtering = false,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (page.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.people_outline,
        title: filtering ? 'No users found' : emptyTitle,
        subtitle: filtering
            ? 'No users match your search or filter.'
            : emptySubtitle,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Column(
          children: [
            if (wide) const AdminUserTableHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                itemCount: page.items.length,
                itemBuilder: (_, index) {
                  final user = page.items[index];
                  return wide
                      ? AdminUserTableRow(
                          user: user,
                          onTap: () => showAdminUserDetailSheet(context, user),
                        )
                      : AdminUserCard(
                          user: user,
                          onTap: () => showAdminUserDetailSheet(context, user),
                        );
                },
              ),
            ),
            AdminUsersPaginationFooter(
              totalCount: page.totalCount,
              itemCount: page.items.length,
              pageIndex: pageIndex,
              pageSize: pageSize,
              onPrev: onPrev,
              onNext: onNext,
            ),
          ],
        );
      },
    );
  }
}

/// Read-only detail sheet built ONLY from the fields returned by
/// `users.admin_list_users` (no extra query, no sensitive tables).
Future<void> showAdminUserDetailSheet(BuildContext context, AdminUser user) {
  return showModalBottomSheet<void>(
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
              value:
                  user.defaultWorkspaceName ?? user.defaultWorkspaceId ?? '—',
            ),
            InfoTileWidget(
              label: 'Entities',
              value: '${user.entityCount}',
            ),
            InfoTileWidget(
              label: 'Joined',
              value: adminUserShortDate(user.createdAt),
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
