import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../presentation/pages/agri_connect_page.dart';

class AgriConnectModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'agri_connect',
      name: 'Agri Connect',
      description: 'Connect farmers, buyers, suppliers, and stakeholders.',
      icon: Icons.people,
      builder: (_) => const AgriConnectPage(),
    );
  }
}
