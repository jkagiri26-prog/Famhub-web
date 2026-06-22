import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../presentation/pages/traceability_page.dart';

class TraceabilityModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'traceability',
      name: 'Traceability',
      description: 'Track agricultural products across the supply chain.',
      icon: Icons.qr_code_scanner,
      builder: (_) => const TraceabilityPage(),
    );
  }
}