import 'package:flutter/material.dart';

import '../../system/models/module_definition.dart';
import '../presentation/pages/opportunities_page.dart';

class OpportunitiesModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'opportunities',
      name: 'Opportunities',
      description: 'Jobs, grants, tenders, funding, and opportunities.',
      icon: Icons.work,
      builder: () => const OpportunitiesPage(),
    );
  }
}