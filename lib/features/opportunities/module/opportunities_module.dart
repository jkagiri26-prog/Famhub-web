import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../presentation/pages/opportunities_page.dart';

class OpportunitiesModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'opportunities',
      name: 'Opportunities',
      description: 'Jobs, grants, tenders, funding, and opportunities.',
      icon: Icons.work,
      builder: (_) => const OpportunitiesPage(),
    );
  }
}