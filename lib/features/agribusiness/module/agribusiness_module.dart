import 'package:flutter/material.dart';

import '../../system/models/module_definition.dart';
import '../presentation/pages/agribusiness_page.dart';

class AgribusinessModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'agribusiness',
      name: 'Agribusiness',
      description: 'Agribusiness operations, partnerships, and enterprise management.',
      icon: Icons.business_center,
      builder: () => const AgribusinessPage(),
    );
  }
}