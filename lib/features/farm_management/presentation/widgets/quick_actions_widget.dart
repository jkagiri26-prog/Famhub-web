/// ============================================================
/// QUICK ACTIONS WIDGET — Farm Dashboard Quick Action Buttons
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/presentation/widgets/ = presentation widgets
///
/// ✅ Responsibilities:
///   - Display quick action shortcuts (Add Field, Record Activity, etc.)
///   - Used as a dashboard widget (farm_quick_actions)
///   - Routes to dedicated pages
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Uses go_router for navigation
///   - Wrapped in ModuleErrorBoundary by the dashboard renderer
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Quick Actions dashboard widget for Farm Management.
///
/// Registered as 'farm_quick_actions' in the WidgetRegistry.
class QuickActionsWidget extends StatelessWidget {
  const QuickActionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionChip(
                context,
                icon: Icons.add_circle,
                label: 'Add Farm',
                color: Colors.green,
                onTap: () => context.push('/farm/create'),
              ),
              _actionChip(
                context,
                icon: Icons.terrain,
                label: 'Add Field',
                color: Colors.brown,
                onTap: () => context.push('/farm/fields/create'),
              ),
              _actionChip(
                context,
                icon: Icons.pets,
                label: 'Add Livestock',
                color: Colors.orange,
                onTap: () => context.push('/farm/livestock/create'),
              ),
              _actionChip(
                context,
                icon: Icons.edit_note,
                label: 'Record Activity',
                color: Colors.blue,
                onTap: () => context.push('/farm/activities'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: color,
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
