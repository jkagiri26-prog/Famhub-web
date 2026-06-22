import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../presentation/pages/knowledge_link_page.dart';

class KnowledgeLinkModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'knowledge_link',
      name: 'Knowledge Link',
      description: 'Agricultural learning, extension content, and knowledge sharing.',
      icon: Icons.menu_book,
      builder: (_) => const KnowledgeLinkPage(),
    );
  }
}