import 'package:flutter/material.dart';

import '../../system/models/module_definition.dart';
import '../presentation/pages/carbon_credit_page.dart';

class CarbonCreditModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'carbon_credit',
      name: 'Carbon Credit',
      description: 'Manage carbon projects, credits, and sustainability metrics.',
      icon: Icons.eco,
      builder: () => const CarbonCreditPage(),
    );
  }
}