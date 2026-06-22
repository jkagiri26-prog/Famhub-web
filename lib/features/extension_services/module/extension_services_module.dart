import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../presentation/pages/extension_services_page.dart';

class ExtensionServicesModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'extension_services',
      name: 'Extension Services',
      description: 'Farmer advisory, field support, and extension operations.',
      icon: Icons.support_agent,
      builder: (_) => const ExtensionServicesPage(),
    );
  }
}