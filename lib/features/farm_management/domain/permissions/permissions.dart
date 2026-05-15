class FarmManagementPermissions {
  // Dashboard access
  static const String viewDashboard =
      'farm_management.view_dashboard';

  // Farm data access
  static const String viewFarms =
      'farm_management.view_farms';

  // Activity management
  static const String manageActivities =
      'farm_management.manage_activities';

  // Production operations
  static const String manageProduction =
      'farm_management.manage_production';

  // Asset management
  static const String manageAssets =
      'farm_management.manage_assets';

  /// All permissions in module
  static const List<String> all = [
    viewDashboard,
    viewFarms,
    manageActivities,
    manageProduction,
    manageAssets,
  ];
}