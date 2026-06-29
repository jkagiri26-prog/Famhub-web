/// ============================================================
/// COMPLETE ENTERPRISE DESKTOP APP BAR (PHASE B)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Responsibilities:
///   - Notifications panel access
///   - Global search access
///   - AI assistant access
///   - Settings access
///   - Profile menu
///   - Context selector
///   - Module status indicator
///   - Every action comes from runtime providers
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Hardcode module lists
///   - Reference registries directly
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/providers/user_provider.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';

/// ============================================================
/// DESKTOP APP BAR
/// ============================================================
class DesktopAppBar extends ConsumerWidget {
  const DesktopAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final moduleAsync = ref.watch(moduleProvider);
    final user = ref.watch(userProvider);
    final context_ = ref.watch(contextProvider);
    final notifications = ref.watch(unreadNotificationCountProvider);

    // Derive module status for indicator
    final moduleCount = moduleAsync.whenOrNull(data: (m) => m.length) ?? 0;
    final hasMaintenance = moduleAsync.whenOrNull(
      data: (modules) => modules.any((m) => m.maintenanceMode),
    ) ?? false;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // ── Left: Context Selector ──
            _ContextSelector(context_: context_),

            const SizedBox(width: 16),

            // ── Module Status Indicator ──
            _ModuleStatusIndicator(
              moduleCount: moduleCount,
              hasMaintenance: hasMaintenance,
            ),

            const Spacer(),

            // ── Right: Actions ──

            // Global Search
            _AppBarActionButton(
              icon: Icons.search_rounded,
              tooltip: 'Global Search (Ctrl+/)',
              onPressed: () => context.go('/search'),
            ),

            const SizedBox(width: 4),

            // AI Assistant
            _AppBarActionButton(
              icon: Icons.auto_awesome_rounded,
              tooltip: 'AI Assistant',
              onPressed: () {
                // Future: AI assistant panel
              },
              color: Colors.purple,
            ),

            const SizedBox(width: 4),

            // Notifications
            _AppBarActionButton(
              icon: Icons.notifications_outlined,
              tooltip: 'Notifications',
              badgeCount: notifications,
              onPressed: () => context.go('/notifications'),
            ),

            const SizedBox(width: 4),

            // Settings
            _AppBarActionButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onPressed: () => context.go('/settings'),
            ),

            const SizedBox(width: 12),

            // ── Divider ──
            Container(
              width: 1,
              height: 32,
              color: Colors.grey.shade200,
            ),

            const SizedBox(width: 12),

            // ── Profile ──
            _ProfileWidget(user: user),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// CONTEXT SELECTOR
/// ============================================================
///
/// Shows the current entity/context and allows switching.
/// Driven by EntityContext from runtime provider.
/// ============================================================
class _ContextSelector extends StatelessWidget {
  final EntityContext context_;

  const _ContextSelector({required this.context_});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Get entity display name from context
    final entityName = context_.entityId ?? 'No Entity';
    final role = context_.role ?? 'user';

    return InkWell(
      onTap: () {
        // Future: context switcher dialog
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.business_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entityName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// MODULE STATUS INDICATOR
/// ============================================================
///
/// Shows live module count and status.
/// Uses moduleProvider to derive status.
/// ============================================================
class _ModuleStatusIndicator extends StatelessWidget {
  final int moduleCount;
  final bool hasMaintenance;

  const _ModuleStatusIndicator({
    required this.moduleCount,
    required this.hasMaintenance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasMaintenance
            ? Colors.orange.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasMaintenance
              ? Colors.orange.shade200
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasMaintenance
                ? Icons.engineering_outlined
                : Icons.check_circle_outline,
            size: 14,
            color: hasMaintenance
                ? Colors.orange.shade700
                : Colors.green.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            '$moduleCount modules',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasMaintenance
                  ? Colors.orange.shade800
                  : Colors.green.shade800,
            ),
          ),
          if (hasMaintenance) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ============================================================
/// APP BAR ACTION BUTTON
/// ============================================================
///
/// Consistent action button with optional badge.
/// ============================================================
class _AppBarActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final int? badgeCount;

  const _AppBarActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? Colors.grey.shade600;

    Widget iconWidget = Icon(icon, color: effectiveColor, size: 22);

    if (badgeCount != null && badgeCount! > 0) {
      iconWidget = Badge(
        label: Text(
          badgeCount.toString(),
          style: const TextStyle(fontSize: 9, color: Colors.white),
        ),
        child: iconWidget,
      );
    }

    return IconButton(
      icon: iconWidget,
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 20,
    );
  }
}

/// ============================================================
/// PROFILE WIDGET
/// ============================================================
///
/// Shows user profile with popup menu for user actions.
/// Uses userProvider for user data.
/// ============================================================
class _ProfileWidget extends ConsumerWidget {
  final AppUser user;

  const _ProfileWidget({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userName = user.displayName;
    final initials = _getInitials(userName);

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            context.go('/profile');
          case 'settings':
            context.go('/settings');
          case 'help':
            // Future: help
          case 'logout':
            // Future: logout
            break;
        }
      },
      itemBuilder: (context) => [
        // ── User Info Header ──
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (user.email != null)
                Text(
                  user.email!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline, size: 20),
            title: Text('Profile'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined, size: 20),
            title: Text('Settings'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'help',
          child: ListTile(
            leading: Icon(Icons.help_outline, size: 20),
            title: Text('Help & Support'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, size: 20, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

/// ============================================================
/// UNREAD NOTIFICATION COUNT PROVIDER
/// ============================================================
///
/// Placeholder provider for notification badge count.
/// Replace with actual notification service provider.
/// ============================================================
final unreadNotificationCountProvider = Provider<int>((ref) {
  // TODO: Replace with actual notification count from NotificationService
  return 0;
});
