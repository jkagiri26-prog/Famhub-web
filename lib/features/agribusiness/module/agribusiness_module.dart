import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../presentation/pages/agribusiness_page.dart';

class AgribusinessModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'agribusiness',
      name: 'Agribusiness',
      description: 'Agribusiness operations, partnerships, and enterprise management.',
      icon: Icons.business_center,
      builder: (_) => const AgribusinessPage(),
    );
  }
}