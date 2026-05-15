import 'package:flutter/material.dart';

import '../../system/models/module_definition.dart';
import '../presentation/pages/analytics_page.dart';

class AnalyticsModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'analytics',
      name: 'Analytics',
      description: 'Platform analytics, KPIs, reports, and insights.',
      icon: Icons.analytics,
      builder: () => const AnalyticsPage(),
    );
  }
}