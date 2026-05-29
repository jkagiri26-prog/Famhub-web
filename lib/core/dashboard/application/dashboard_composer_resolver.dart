import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardComposerResolver {
  final String userRole;
  final String? activeEntity;
  final String subscriptionPlan;
  final List<String> enabledModules;
  final Map<String, bool> featureFlags;
  final bool maintenanceMode;
  final Map<String, bool> accessPermissions;

  DashboardComposerResolver({
    required this.userRole,
    this.activeEntity,
    required this.subscriptionPlan,
    required this.enabledModules,
    required this.featureFlags,
    required this.maintenanceMode,
    required this.accessPermissions,
  });

  String resolveDashboardContext() {
    if (maintenanceMode) {
      return 'maintenance';
    }

    if (!enabledModules.contains('dashboard')) {
      return 'no_dashboard';
    }

    if (accessPermissions['dashboard'] == false) {
      return 'access_denied';
    }

    return 'dashboard';
  }

  static final provider = Provider<DashboardComposerResolver>((ref) {
    // Replace with actual logic to fetch user context
    return DashboardComposerResolver(
      userRole: 'user',
      activeEntity: null,
      subscriptionPlan: 'basic',
      enabledModules: ['dashboard'],
      featureFlags: {'new_dashboard': true},
      maintenanceMode: false,
      accessPermissions: {'dashboard': true},
    );
  });
}