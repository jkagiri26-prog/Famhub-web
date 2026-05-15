import 'package:flutter/material.dart';

import '../../system/models/module_definition.dart';
import '../presentation/pages/extension_services_page.dart';

class ExtensionServicesModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'extension_services',
      name: 'Extension Services',
      description: 'Farmer advisory, field support, and extension operations.',
      icon: Icons.support_agent,
      builder: () => const ExtensionServicesPage(),
    );
  }
}