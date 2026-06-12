import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_definition.dart';
import '../presentation/pages/agri_connect_page.dart';

class AgriConnectModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'agri_connect',
      name: 'Agri Connect',
      description: 'Connect farmers, buyers, suppliers, and stakeholders.',
      icon: Icons.people,
      builder: () => const AgriConnectPage(),
    );
  }