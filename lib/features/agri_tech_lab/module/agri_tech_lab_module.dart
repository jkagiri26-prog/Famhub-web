import 'package:flutter/material.dart';

import '../../system/models/module_definition.dart';
import '../presentation/pages/agri_tech_lab_page.dart';

class AgriTechLabModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'agri_tech_lab',
      name: 'Agri Tech Lab',
      description: 'AI, smart farming, research, and agricultural innovation.',
      icon: Icons.science,
      builder: () => const AgriTechLabPage(),
    );
  }
}