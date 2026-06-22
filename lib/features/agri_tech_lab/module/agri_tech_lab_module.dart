import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../presentation/pages/agri_tech_lab_page.dart';

class AgriTechLabModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'agri_tech_lab',
      name: 'Agri Tech Lab',
      description: 'AI, smart farming, research, and agricultural innovation.',
      icon: Icons.science,
      builder: (_) => const AgriTechLabPage(),
    );
  }
}