import 'package:flutter/material.dart';

import '../../shared/models/module_definition.dart';
import '../presentation/pages/traceability_page.dart';

class TraceabilityModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'traceability',
      name: 'Traceability',
      description: 'Track agricultural products across the supply chain.',
      icon: Icons.qr_code_scanner,
      builder: () => const TraceabilityPage(),
    );
  }
}