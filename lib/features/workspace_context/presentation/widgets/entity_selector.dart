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
import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';
import 'package:famhub_app/features/workspace_context/application/entity_context_refresh.dart';
import 'package:famhub_app/features/workspace_context/application/entity_identity_provider.dart';

/// Compact active-entity chip for page headers.
///
/// Hides itself while contexts are loading or when the active workspace has
/// no entity contexts (e.g. global/platform pages). Includes its own bottom
/// spacing so callers can place it directly under a page title.
class EntitySelector extends ConsumerWidget {
  /// Optional page-provided name (farm / business profile) to show instead of
  /// the context's generic entity name.
  final String? primaryLabel;

  /// Selected farm id (farmer workspace) used to resolve the farm location.
  final String? farmId;

  /// Active business profile id (trader/institution) used to resolve the
  /// business location.
  final String? businessProfileId;

  const EntitySelector({
    super.key,
    this.primaryLabel,
    this.farmId,
    this.businessProfileId,
  });

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

    final workspaceType = ref.watch(activeWorkspaceTypeProvider);
    final entityId = activeContext?['entity_id']?.toString() ??
        activeEntityId ??
        '';

    final identity = ref
            .watch(entityIdentityProvider((
              entityId: entityId,
              workspaceType: workspaceType,
              farmId: farmId,
              businessProfileId: businessProfileId,
            )))
            .value ??
        const EntityIdentity();

    final override = primaryLabel?.trim();
    final entityName =
        activeContext != null ? _entityLabel(activeContext) : 'Entity';
    final label =
        (override != null && override.isNotEmpty) ? override : entityName;
    final canSwitch = contexts.length > 1;

    final location = identity.location?.trim();
    final ownerName = identity.ownerName?.trim();
    final relationship = activeContext == null
        ? null
        : _relationshipLabel(activeContext);
    final secondLineParts = <String>[
      if (ownerName != null && ownerName.isNotEmpty) ownerName,
      if (relationship != null && relationship.isNotEmpty) relationship,
    ];
    final secondLine =
        secondLineParts.isEmpty ? null : secondLineParts.join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSwitch
              ? () => _openEntitySwitcher(context, ref, palette)
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      _workspaceIcon(workspaceType),
                      size: 18,
                      color: palette.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: palette.primaryText,
                              ),
                            ),
                            if (location != null && location.isNotEmpty)
                              TextSpan(
                                text: ' — $location',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: palette.secondaryText,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canSwitch) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.expand_more,
                        size: 18,
                        color: palette.secondaryText,
                      ),
                    ],
                  ],
                ),
                if (secondLine != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 26, top: 2),
                    child: Text(
                      secondLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.1,
                        color: palette.secondaryText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _workspaceIcon(String? workspaceType) {
    switch (workspaceType) {
      case 'farmer':
        return Icons.agriculture_outlined;
      case 'trader':
        return Icons.business_outlined;
      case 'institution':
        return Icons.account_balance_outlined;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.business_outlined;
    }
  }

  /// Human-readable relationship for the active context.
  ///
  /// Uses the role attached to the selected entity/context, falling back to
  /// the active mode and finally to the generic "Operating entity".
  String _relationshipLabel(Map<String, dynamic> c) {
    final role = (c['role_name'] ?? c['active_mode'])?.toString().trim();
    if (role == null || role.isEmpty) return 'Operating entity';
    final humanized = role.replaceAll('_', ' ').trim();
    if (humanized.isEmpty) return 'Operating entity';
    return humanized[0].toUpperCase() + humanized.substring(1);
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
