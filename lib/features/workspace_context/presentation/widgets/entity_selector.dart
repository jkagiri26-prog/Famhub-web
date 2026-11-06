/// ============================================================
/// ENTITY SELECTOR — page-level active entity switcher
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/workspace_context/presentation/widgets/ =
///   workspace-context presentation
///
/// ✅ Responsibilities:
///   - Show the human-readable active entity for the current workspace
///   - List only contexts authorized for the active workspace
///   - Switch the active entity through the existing
///     `ContextController.activateContextRow(...)` path and
///     `refreshEntityScopedProviders`
///
/// ❌ Does NOT:
///   - Change the workspace or navigate
///   - Create a second entity/context state
///   - Render when the active workspace has no entity contexts
///
/// This is the same entity-switching implementation that previously lived
/// in the global shell app bar, now rendered in the operational page header.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/theme/shell_theme.dart';
import 'package:famhub_app/core/workspace/application/current_workspace_contexts_provider.dart';
import 'package:famhub_app/features/workspace_context/application/entity_context_refresh.dart';

/// Compact active-entity chip for page headers.
///
/// Hides itself while contexts are loading or when the active workspace has
/// no entity contexts (e.g. global/platform pages). Includes its own bottom
/// spacing so callers can place it directly under a page title.
class EntitySelector extends ConsumerWidget {
  const EntitySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;

    final activeEntityId =
        ref.watch(contextProvider.select((c) => c.entityId));
    final contexts =
        ref.watch(currentWorkspaceContextsProvider).value ?? const [];

    if (contexts.isEmpty) return const SizedBox.shrink();

    Map<String, dynamic>? activeContext;
    for (final c in contexts) {
      if (c['entity_id']?.toString() == activeEntityId) {
        activeContext = c;
        break;
      }
    }

    final label =
        activeContext != null ? _entityLabel(activeContext) : 'Entity';
    final canSwitch = contexts.length > 1;
    final subtitle = activeContext == null ? null : _entitySubtitle(activeContext);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: canSwitch
              ? () => _openEntitySwitcher(context, ref, palette)
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.border),
              borderRadius: BorderRadius.circular(10),
            ),
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
                    Icons.business_outlined,
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
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.primaryText,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.secondaryText,
                        ),
                      )
                    else if (canSwitch)
                      Text(
                        'Switch entity',
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.secondaryText,
                        ),
                      ),
                  ],
                ),
                if (canSwitch) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: palette.secondaryText,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEntitySwitcher(
    BuildContext context,
    WidgetRef ref,
    ShellColorPalette palette,
  ) async {
    final contexts =
        await ref.read(currentWorkspaceContextsProvider.future);
    if (contexts.length <= 1 || !context.mounted) return;

    final activeEntityId = ref.read(contextProvider).entityId;

    await showModalBottomSheet<void>(
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
                'Switch entity',
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
                itemCount: contexts.length,
                itemBuilder: (_, index) {
                  final c = contexts[index];
                  final entityId = c['entity_id']?.toString();
                  final isActive =
                      entityId != null && entityId == activeEntityId;
                  final subtitle = _entitySubtitle(c);
                  return ListTile(
                    leading: Icon(
                      isActive
                          ? Icons.check_circle
                          : Icons.business_outlined,
                      color: isActive
                          ? palette.primary
                          : palette.secondaryText,
                    ),
                    title: Text(
                      _entityLabel(c),
                      style: TextStyle(color: palette.primaryText),
                    ),
                    subtitle: subtitle == null
                        ? null
                        : Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.secondaryText,
                            ),
                          ),
                    trailing: isActive
                        ? Icon(Icons.check, color: palette.primary)
                        : null,
                    selected: isActive,
                    onTap: () async {
                      final ok = await _activateEntityContext(ref, c);
                      if (!sheetContext.mounted) return;
                      if (ok) {
                        Navigator.pop(sheetContext);
                      } else {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Could not switch entity. Please try again.'),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Canonical same-workspace ENTITY activation (existing architecture).
  Future<bool> _activateEntityContext(
    WidgetRef ref,
    Map<String, dynamic> c,
  ) async {
    final workspaceId = c['workspace_id']?.toString();
    final entityId = c['entity_id']?.toString();
    final roleId = c['role_id']?.toString();
    if (workspaceId == null ||
        workspaceId.isEmpty ||
        entityId == null ||
        entityId.isEmpty ||
        roleId == null ||
        roleId.isEmpty) {
      return false;
    }

    final applied = await ref
        .read(contextProvider.notifier)
        .activateContextRow(
          workspaceId: workspaceId,
          entityId: entityId,
          roleId: roleId,
          activeMode: c['active_mode']?.toString() ?? '',
          businessProfileId: c['business_profile_id']?.toString(),
        );
    if (applied == null) return false;

    // Same workspace: stay in place and refresh entity-scoped data.
    refreshEntityScopedProviders(ref);
    return true;
  }

  String _entityLabel(Map<String, dynamic> c) {
    final named = c['entity_name'] ??
        c['entity_display_name'] ??
        c['entity_slug'] ??
        c['name'];
    if (named != null && named.toString().trim().isNotEmpty) {
      return named.toString();
    }
    // Never surface a raw UUID in the UI.
    return 'Entity';
  }

  String? _entitySubtitle(Map<String, dynamic> c) {
    final role = (c['role_name'] ?? c['active_mode'])?.toString();
    final businessProfile =
        (c['business_profile_name'] ?? c['supplier_name'])?.toString();
    final parts = <String>[
      if (role != null && role.isNotEmpty) role,
      if (businessProfile != null && businessProfile.isNotEmpty)
        businessProfile,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
