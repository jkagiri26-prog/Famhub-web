import 'package:flutter/material.dart';

import '../../../features/system/models/module_definition.dart';
import '../presentation/pages/unified_dashboard_host.dart';

class DashboardModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'dashboard',
      name: 'Dashboard',
      description: 'Unified FAMHUB dashboard.',
      icon: Icons.dashboard,

      /// FIX: pass moduleKey explicitly
      builder: (context) => const UnifiedDashboardHost(
        moduleKey: 'dashboard',
      ),
    );
  }
}