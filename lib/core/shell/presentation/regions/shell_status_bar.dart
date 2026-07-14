/// ============================================================
/// SHELL STATUS BAR — Domain-agnostic status bar
/// ============================================================
///
/// 🎯 PURPOSE:
///   Status bar region showing system information (connection status,
///   sync status, etc.). All colors from ShellTheme.
///   Configurable via StatusBarConfig.
///
/// ✅ Domain-Agnostic:
///   - No agriculture-specific information
///   - Shows generic system status indicators
///   - Connection, sync, and custom items
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/shell_theme.dart';
import '../../config/shell_config.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/sync_state_provider.dart';

/// ============================================================
/// SHELL STATUS BAR
/// ============================================================
class ShellStatusBar extends ConsumerWidget {
  final StatusBarConfig config;

  const ShellStatusBar({super.key, this.config = const StatusBarConfig()});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!config.visible) return const SizedBox.shrink();

    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;

    return Container(
      height: config.height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.statusBarBg,
        border: Border(
          top: BorderSide(color: palette.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          // ── Left items ──
          ...config.leftItems.map((item) => _StatusItem(item: item, palette: palette)),

          if (config.showConnectionStatus) ...[
            if (config.leftItems.isNotEmpty) const SizedBox(width: 12),
            _ConnectionStatus(palette: palette),
          ],

          const Spacer(),

          // ── Sync status ──
          if (config.showSyncStatus) _SyncStatus(palette: palette),

          // ── Right items ──
          ...config.rightItems.map((item) => _StatusItem(item: item, palette: palette)),
        ],
      ),
    );
  }
}

/// ============================================================
/// STATUS ITEM
/// ============================================================
class _StatusItem extends StatelessWidget {
  final ShellStatusItem item;
  final ShellColorPalette palette;

  const _StatusItem({required this.item, required this.palette});

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? palette.statusBarText;

    return GestureDetector(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// CONNECTION STATUS
/// ============================================================
class _ConnectionStatus extends ConsumerWidget {
  final ShellColorPalette palette;

  const _ConnectionStatus({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityProvider);
    final isConnected = connectivityAsync.whenOrNull(
      data: (connected) => connected,
    ) ?? true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isConnected ? palette.success : palette.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? 'Connected' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              color: palette.statusBarText,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// SYNC STATUS
/// ============================================================
class _SyncStatus extends ConsumerWidget {
  final ShellColorPalette palette;

  const _SyncStatus({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          syncState == SyncStatus.syncing
              ? SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.info,
                  ),
                )
              : Icon(
                  syncState == SyncStatus.error
                      ? Icons.sync_problem
                      : Icons.sync,
                  size: 12,
                  color: syncState == SyncStatus.error
                      ? palette.warning
                      : palette.statusBarText,
                ),
          const SizedBox(width: 4),
          Text(
            _syncLabel(syncState),
            style: TextStyle(
              fontSize: 11,
              color: palette.statusBarText,
            ),
          ),
        ],
      ),
    );
  }

  String _syncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.pending:
        return 'Pending sync';
      case SyncStatus.error:
        return 'Sync error';
    }
  }
}

