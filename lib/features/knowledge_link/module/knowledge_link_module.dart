import 'package:flutter/material.dart';

import '../../system/models/module_definition.dart';
import '../presentation/pages/knowledge_link_page.dart';

class KnowledgeLinkModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'knowledge_link',
      name: 'Knowledge Link',
      description: 'Agricultural learning, extension content, and knowledge sharing.',
      icon: Icons.menu_book,
      builder: () => const KnowledgeLinkPage(),
    );
  }
}