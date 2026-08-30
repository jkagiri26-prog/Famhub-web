/// ============================================================
/// SHELL APP BAR — Domain-agnostic desktop app bar
/// ============================================================
///
/// 🎯 PURPOSE:
///   Replace agriculture-specific DesktopAppBar with a neutral,
///   configurable app bar. All colors from ShellTheme.
///   No hardcoded icons, colors, or brand references.
///
/// ✅ Domain-Agnostic:
///   - No agriculture-specific icons or colors
///   - All actions configurable via TopBarConfig
///   - Context selector, notifications, search, settings all optional
///   - Profile menu with configurable actions
///   - Module status indicator (not farm-specific)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/shell_theme.dart';
import '../../../navigation/responsive_breakpoints.dart';
import '../../config/shell_config.dart';
import '../../../providers/module_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/notification_count_provider.dart';
import '../../../workspace/application/active_workspace_provider.dart';
import '../../../workspace/application/workspace_catalog_provider.dart';
import '../../../workspace/application/workspace_dashboard_provider.dart';
import '../../../workspace/domain/workspace_catalog_item.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/session/session_provider.dart';

/// ============================================================
/// SHELL APP BAR — Replaces DesktopAppBar
/// ============================================================
class ShellAppBar extends ConsumerWidget {
  final TopBarConfig config;

  const ShellAppBar({super.key, this.config = const TopBarConfig()});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!config.visible) return const SizedBox.shrink();

    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;
    final moduleAsync = ref.watch(moduleProvider);
    final user = ref.watch(userProvider);

    final moduleCount = moduleAsync.whenOrNull(data: (m) => m.length) ?? 0;
    final hasMaintenance = moduleAsync.whenOrNull(
      data: (modules) => modules.any((m) => m.maintenanceMode),
    ) ?? false;

    return Container(
      height: config.height,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          bottom: BorderSide(color: palette.border),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow =
              constraints.maxWidth < ResponsiveBreakpoints.mobile;

          final leftChildren = <Widget>[
            // ── Left: Context Selector ──
            if (config.showContextSelector)
              _ContextSelector(palette: palette),

            if (config.showContextSelector) const SizedBox(width: 16),

            // ── Module Status Indicator ──
            // Hidden on narrow (mobile) screens to free horizontal space for
            // primary actions; module count data/provider is unchanged.
            if (config.showModuleStatus && !isNarrow)
              _ModuleStatusIndicator(
                moduleCount: moduleCount,
                hasMaintenance: hasMaintenance,
                palette: palette,
              ),
          ];

          final rightChildren = <Widget>[
            // ── Right: Actions ──

            // Custom actions
            ...config.customActions.map((action) => _buildCustomAction(action, palette)),

            if (config.customActions.isNotEmpty) const SizedBox(width: 4),

            // Global Search
            if (config.showSearch)
              _AppBarButton(
                icon: Icons.search_rounded,
                tooltip: 'Search (Ctrl+/)',
                palette: palette,
                onPressed: () => context.go('/search'),
              ),

            if (config.showSearch) const SizedBox(width: 4),

            // AI Assistant
            if (config.showAiAssistant)
              _AppBarButton(
                icon: Icons.auto_awesome_rounded,
                tooltip: 'AI Assistant',
                palette: palette,
                color: palette.info,
                onPressed: () {
                  // Future: AI assistant panel
                },
              ),

            if (config.showAiAssistant) const SizedBox(width: 4),

            // Notifications
            if (config.showNotifications)
              _AppBarButton(
                icon: Icons.notifications_outlined,
                tooltip: 'Notifications',
                palette: palette,
                onPressed: () => context.go('/notifications'),
                badgeCount: ref.watch(unreadNotificationCountProvider),
              ),

            if (config.showNotifications) const SizedBox(width: 4),

            // Settings
            if (config.showSettings)
              _AppBarButton(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                palette: palette,
                onPressed: () => context.go('/settings'),
              ),

            if (config.showSettings) const SizedBox(width: 12),

            // ── Divider ──
            if (config.showProfile)
              Container(
                width: 1,
                height: 32,
                color: palette.divider,
              ),

            if (config.showProfile) const SizedBox(width: 12),

            // ── Profile ──
            if (config.showProfile)
              _ProfileWidget(user: user, palette: palette),
          ];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isNarrow
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...leftChildren,
                        if (leftChildren.isNotEmpty) const SizedBox(width: 12),
                        ...rightChildren,
                      ],
                    ),
                  )
                : Row(
                    children: [
                      ...leftChildren,
                      const Spacer(),
                      ...rightChildren,
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCustomAction(ShellAction action, ShellColorPalette palette) {
    Widget iconWidget = Icon(
      action.icon,
      color: action.color ?? palette.secondaryText,
      size: 22,
    );

    if (action.showBadge && action.badgeText != null) {
      iconWidget = Badge(
        label: Text(
          action.badgeText!,
          style: const TextStyle(fontSize: 9, color: Colors.white),
        ),
        child: iconWidget,
      );
    }

    return IconButton(
      icon: iconWidget,
      tooltip: action.tooltip,
      onPressed: action.onPressed,
      splashRadius: 20,
    );
  }
}

/// ============================================================
/// CONTEXT SELECTOR — Active workspace switcher
/// ============================================================
class _ContextSelector extends ConsumerWidget {
  final ShellColorPalette palette;

  const _ContextSelector({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceName =
        ref.watch(activeWorkspaceNameProvider) ?? 'Workspace';
    final session = ref.watch(sessionProvider);
    final workspaceIds = session is AuthenticatedSession
        ? session.workspaceIds
        : const <String>[];

    return InkWell(
      onTap: () => _openWorkspaceSwitcher(context, ref),
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
                color: palette.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.workspaces_outline,
                size: 16,
                color: palette.primary,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  workspaceName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.primaryText,
                  ),
                ),
                Text(
                  workspaceIds.length > 1
                      ? 'Switch workspace'
                      : 'Workspace',
                  style: TextStyle(
                    fontSize: 10,
                    color: palette.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: palette.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a switcher listing the authenticated user's already-selected
  /// workspaces. Switching updates the active workspace (in-memory +
  /// local snapshot); the Dashboard recomposes from the new workspace.
  Future<void> _openWorkspaceSwitcher(
      BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionProvider);
    if (session is! AuthenticatedSession ||
        session.workspaceIds.isEmpty) {
      return;
    }

    final catalog = ref.read(workspaceCatalogProvider).asData?.value ??
        const <WorkspaceCatalogItem>[];
    final items = <WorkspaceCatalogItem>[
      for (final id in session.workspaceIds)
        for (final w in catalog)
          if (w.id == id) w,
    ];
    if (items.isEmpty) return;

    final active = ref.read(activeWorkspaceProvider);

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Switch workspace',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.primaryText,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = item.id == active.workspaceId;
                  return ListTile(
                    leading: Icon(Icons.workspaces_outline,
                        color: isActive
                            ? palette.primary
                            : palette.secondaryText),
                    title: Text(
                      item.name,
                      style: TextStyle(color: palette.primaryText),
                    ),
                    subtitle: item.category != null
                        ? Text(
                            item.category!,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.secondaryText,
                            ),
                          )
                        : null,
                    trailing: isActive
                        ? Icon(Icons.check, color: palette.primary)
                        : null,
                    selected: isActive,
                    onTap: () => Navigator.pop(sheetContext, item.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (selected != null && selected != active.workspaceId) {
      await ref
          .read(activeWorkspaceProvider.notifier)
          .switchWorkspace(selected);
      // Surface the newly-selected workspace Dashboard.
      if (context.mounted) {
        context.go('/');
      }
    }
  }
}

/// ============================================================
/// MODULE STATUS INDICATOR
/// ============================================================
class _ModuleStatusIndicator extends StatelessWidget {
  final int moduleCount;
  final bool hasMaintenance;
  final ShellColorPalette palette;

  const _ModuleStatusIndicator({
    required this.moduleCount,
    required this.hasMaintenance,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasMaintenance ? palette.warningBg : palette.successBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasMaintenance
              ? palette.warning.withValues(alpha: 0.3)
              : palette.success.withValues(alpha: 0.3),
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
            color: hasMaintenance ? palette.warning : palette.success,
          ),
          const SizedBox(width: 6),
          Text(
            '$moduleCount services',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasMaintenance ? palette.warning : palette.success,
            ),
          ),
          if (hasMaintenance) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: palette.warning,
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
/// APP BAR BUTTON
/// ============================================================
class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final ShellColorPalette palette;
  final VoidCallback? onPressed;
  final Color? color;
  final int? badgeCount;

  const _AppBarButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    this.onPressed,
    this.color,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? palette.secondaryText;

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
class _ProfileWidget extends ConsumerWidget {
  final AppUser user;
  final ShellColorPalette palette;

  const _ProfileWidget({required this.user, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = user.displayName;
    final initials = _getInitials(userName);

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            context.go('/profile');
          case 'settings':
            context.go('/settings');
          case 'help':
            // Future: help
          case 'logout':
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Sign Out',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(sessionProvider.notifier).signOut();
            }
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: palette.primaryText,
                ),
              ),
              if (user.email != null)
                Text(
                  user.email!,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.secondaryText,
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline, size: 20,
                color: palette.secondaryText),
            title: Text('Profile',
                style: TextStyle(color: palette.primaryText)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined, size: 20,
                color: palette.secondaryText),
            title: Text('Settings',
                style: TextStyle(color: palette.primaryText)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'help',
          child: ListTile(
            leading: Icon(Icons.help_outline, size: 20,
                color: palette.secondaryText),
            title: Text('Help & Support',
                style: TextStyle(color: palette.primaryText)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, size: 20, color: palette.error),
            title: Text('Logout', style: TextStyle(color: palette.error)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: palette.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.primary,
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
