import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../presentation/pages/analytics_page.dart';

class AnalyticsModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'analytics',
      name: 'Analytics',
      description: 'Platform analytics, KPIs, reports, and insights.',
      icon: Icons.analytics,
      builder: (_) => const AnalyticsPage(),
    );
  }
}