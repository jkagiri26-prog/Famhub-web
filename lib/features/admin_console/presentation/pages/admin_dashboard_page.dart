import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/governance_summary_card.dart';
import '../widgets/feature_toggle_tile.dart';
import '../widgets/module_control_tile.dart';
import '../widgets/role_permission_editor.dart';
import '../widgets/subscription_tier_editor.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GovernanceSummaryCards(),
          SizedBox(height: 24),

          /// Feature flags control
          Text(
            'Feature Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          FeatureToggleTile(
            featureKey: 'ai_advisory',
            isEnabled: true,
          ),
          FeatureToggleTile(
            featureKey: 'carbon_tracking',
            isEnabled: true,
          ),
          FeatureToggleTile(
            featureKey: 'advanced_reporting',
            isEnabled: false,
          ),

          SizedBox(height: 32),

          /// Module governance
          Text(
            'Module Governance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          ModuleControlTile(
            moduleKey: 'farm_management',
            isEnabled: true,
          ),
          ModuleControlTile(
            moduleKey: 'marketplace',
            isEnabled: true,
          ),
          ModuleControlTile(
            moduleKey: 'logistics',
            isEnabled: false,
          ),

          SizedBox(height: 32),

          /// Role permissions
          Text(
            'Role Permissions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          RolePermissionEditor(),

          SizedBox(height: 32),

          /// Subscription governance
          Text(
            'Subscription Governance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          SubscriptionTierEditor(),
        ],
      ),
    );
  }
}