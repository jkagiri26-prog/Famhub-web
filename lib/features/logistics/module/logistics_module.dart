import 'package:flutter/material.dart';

import '../../../system/modules_control/module_contract.dart';
import '../presentation/pages/logistics_page.dart';

class LogisticsModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'logistics',
      name: 'Logistics',
      description:
          'Transportation, delivery coordination, fleet tracking, and supply chain logistics.',
      icon: Icons.local_shipping,
      builder: () => const LogisticsPage(),
    );
  }
}