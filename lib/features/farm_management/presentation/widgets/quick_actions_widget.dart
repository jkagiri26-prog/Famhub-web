/// ============================================================
/// QUICK ACTIONS WIDGET — Hierarchy-Aware Dashboard Actions
/// ============================================================
///
/// 🏗️ HIERARCHY RULE:
///   Display only actions that make sense for the current hierarchy level.
///
///   Farm Level:        Add Field
///   Field Level:        Add Crop, Add Livestock, Edit Field (no Activity yet)
///   Crop/Livestock:     Record Activity, View Crop, Harvest, Irrigation, etc.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/presentation/navigation/farm_action_navigation.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_farm_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_field_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_crop_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_livestock_page.dart';

/// Quick Actions dashboard widget for Farm Management.
///
/// Registered as 'farm_quick_actions' in the WidgetRegistry.
/// Automatically adapts available actions based on hierarchy depth.
class QuickActionsWidget extends ConsumerWidget {
  const QuickActionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hierarchy = ref.watch(hierarchyProvider);
    final theme = Theme.of(context);

    // Determine what actions to show based on hierarchy depth
    final actions = _getAvailableActions(context, ref, hierarchy);

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getSectionTitle(hierarchy),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions.map((action) => _buildActionChip(
              context,
              action: action,
              hierarchy: hierarchy,
            )).toList(),
          ),
        ],
      ),
    );
  }

  /// Get title based on current hierarchy level
  String _getSectionTitle(HierarchySelectionState hierarchy) {
    if (hierarchy.hasCropOrLivestock) {
      return 'Actions for ${hierarchy.cropOrLivestockType == 'crop' ? 'Crop' : 'Livestock'}';
    }
    if (hierarchy.hasField) {
      return 'Actions for ${hierarchy.field!.fieldName}';
    }
    if (hierarchy.hasEntity) {
      return 'Farm Actions';
    }
    return 'Quick Actions';
  }

  /// Hierarchy-aware action definitions
  List<_QuickAction> _getAvailableActions(
    BuildContext context,
    WidgetRef ref,
    HierarchySelectionState hierarchy,
  ) {
    final actions = <_QuickAction>[];

    if (!hierarchy.hasEntity) {
      // No farm selected — only option is to add one
      actions.add(_QuickAction(
        key: 'add_farm',
        icon: Icons.add_circle,
        label: 'Add Farm',
        color: Colors.green,
        route: '/farm/create',
        showIf: () => true,
        open: () => _openPage(context, (_) => const AddFarmPage()),
      ));
      return actions;
    }

    // ── Always available at farm level ──
    actions.add(_QuickAction(
      key: 'add_field',
      icon: Icons.terrain,
      label: 'Add Field',
      color: Colors.brown,
      route: '/farm/fields/create',
      showIf: () => true,
      open: () => _openPage(context, (_) => const AddFieldPage()),
    ));

    // ── Field level actions (no Crop/Livestock selected) ──
    if (hierarchy.hasField && !hierarchy.hasCropOrLivestock) {
      actions.add(_QuickAction(
        key: 'add_crop',
        icon: Icons.eco,
        label: 'Add Crop',
        color: Colors.green,
        route: '/farm/crops/create',
        showIf: () => true,
        open: () => ensureFieldSelectedAndOpen(
          context,
          ref,
          (_) => const AddCropPage(),
        ),
      ));
      actions.add(_QuickAction(
        key: 'add_livestock',
        icon: Icons.pets,
        label: 'Add Livestock',
        color: Colors.orange,
        route: '/farm/livestock/create',
        showIf: () => true,
        open: () => ensureFieldSelectedAndOpen(
          context,
          ref,
          (_) => const AddLivestockPage(),
        ),
      ));
      actions.add(_QuickAction(
        key: 'edit_field',
        icon: Icons.edit,
        label: 'Edit Field',
        color: Colors.blueGrey,
        route: '/farm/fields/${hierarchy.fieldId}/edit',
        showIf: () => true,
      ));
    }

    // ── Crop/Livestock level actions (full hierarchy) ──
    if (hierarchy.hasCropOrLivestock) {
      actions.add(_QuickAction(
        key: 'record_activity',
        icon: Icons.edit_note,
        label: 'Record Activity',
        color: Colors.blue,
        route: '/farm/activities/record',
        showIf: () => true,
      ));
      if (hierarchy.cropOrLivestockType == 'crop') {
        actions.add(_QuickAction(
          key: 'harvest',
          icon: Icons.yard,
          label: 'Harvest',
          color: Colors.amber,
          route: '/farm/crops/${hierarchy.cropOrLivestockId}/harvest',
          showIf: () => true,
        ));
        actions.add(_QuickAction(
          key: 'irrigation',
          icon: Icons.water_drop,
          label: 'Irrigation',
          color: Colors.lightBlue,
          route: '/farm/crops/${hierarchy.cropOrLivestockId}/irrigate',
          showIf: () => true,
        ));
        actions.add(_QuickAction(
          key: 'fertilizer',
          icon: Icons.biotech,
          label: 'Fertilizer',
          color: Colors.teal,
          route: '/farm/crops/${hierarchy.cropOrLivestockId}/fertilize',
          showIf: () => true,
        ));
      }
      actions.add(_QuickAction(
        key: 'view_report',
        icon: Icons.assessment,
        label: 'View Report',
        color: Colors.purple,
        route: '/farm/reports',
        showIf: () => true,
      ));
    }

    return actions;
  }

  Widget _buildActionChip(
    BuildContext context, {
    required _QuickAction action,
    required HierarchySelectionState hierarchy,
  }) {
    return ActionChip(
      avatar: Icon(action.icon, size: 16, color: Colors.white),
      label: Text(
        action.label,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: action.color,
      onPressed: action.open ?? () => context.push(action.route),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  void _openPage(BuildContext context, WidgetBuilder pageBuilder) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: pageBuilder),
    );
  }
}

/// Internal quick action definition
class _QuickAction {
  final String key;
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  final bool Function() showIf;

  /// When set, opens the page directly (with the required hierarchy
  /// context) instead of pushing the (unregistered) [route].
  final VoidCallback? open;

  const _QuickAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
    required this.showIf,
    this.open,
  });
}
