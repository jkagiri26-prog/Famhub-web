import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../presentation/pages/carbon_credit_page.dart';

class CarbonCreditModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'carbon_credit',
      name: 'Carbon Credit',
      description: 'Manage carbon projects, credits, and sustainability metrics.',
      icon: Icons.eco,
      builder: (_) => const CarbonCreditPage(),
    );
  }
}