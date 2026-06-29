import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import 'package:famhub_app/features/farm_management/config/permissions.dart';

class FarmManagementModule extends AppModule {
  static const String moduleId = 'farm_management';
  static const String displayName = 'Farm Management';
  static const IconData icon = Icons.agriculture;

  FarmManagementModule();

  List<String> get permissions => FarmManagementPermissions.all;

  @override
  String get name => moduleId;

  @override
  String get route => '/farm';

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
}

