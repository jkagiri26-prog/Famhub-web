import 'package:flutter/material.dart';

import '../../../system/module/module_contract.dart';
import '../domain/permissions/permissions.dart';
import '../presentation/pages/activities_page.dart';
import '../presentation/pages/assets_page.dart';
import '../presentation/pages/crops_page.dart';
import '../presentation/pages/farm_dashboard_page.dart';
import '../presentation/pages/farms_page.dart';
import '../presentation/pages/fields_page.dart';
import '../presentation/pages/livestock_page.dart';
import '../presentation/pages/production_page.dart';
import 'farm_management_registry.dart';

class FarmManagementModule extends AppModule {
  static const String moduleId = 'farm_management';
  static const String displayName = 'Farm Management';
  static const IconData icon = Icons.agriculture;

  const FarmManagementModule();

  /// Lazy initialization hook for dashboard widgets / registries.
  void ensureInitialized() {
    FarmManagementRegistry.ensureInitialized();
  }

  List<String> get permissions => FarmManagementPermissions.all;

  Map<String, WidgetBuilder> get routes => {
        '/farm-management': (_) => const FarmDashboardPage(),
        '/farm-management/farms': (_) => const FarmsPage(),
        '/farm-management/fields': (_) => const FieldsPage(),
        '/farm-management/crops': (_) => const CropsPage(),
        '/farm-management/livestock': (_) => const LivestockPage(),
        '/farm-management/production': (_) => const ProductionPage(),
        '/farm-management/activities': (_) => const ActivitiesPage(),
        '/farm-management/assets': (_) => const AssetsPage(),
      };

  @override
  String get name => moduleId;

  @override
  String get route => '/farm-management';

  @override
  List<String> get allowedRoles => const [
        'farmer',
        'cooperative',
        'agribusiness',
        'admin',
      ];

  @override
  List<String> get dashboardWidgets => const [
        'farm_farm_selector',
        'farm_kpis',
        'farm_activity_timeline',
        'farm_production_summary',
        'farm_stock_summary',
        'farm_alerts',
        'farm_quick_actions',
      ];

  @override
  Widget build() {
    ensureInitialized();
    return const FarmDashboardPage();
  }
}

