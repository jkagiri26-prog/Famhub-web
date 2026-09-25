import 'package:flutter/material.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/cards/empty_state_card_widget.dart';

import '../widgets/knowledge_category_chips_widget.dart';
import '../widgets/knowledge_browse_guides_widget.dart';
import '../widgets/knowledge_quick_access_widget.dart';

class KnowledgeLinkPage extends StatefulWidget {
  const KnowledgeLinkPage({super.key});

  @override
  State<KnowledgeLinkPage> createState() => _KnowledgeLinkPageState();
}

class _KnowledgeLinkPageState extends State<KnowledgeLinkPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<String> categories = const [
    "Best Practices",
    "Pest Control",
    "Soil Health",
    "Markets",
    "Livestock",
    "Climate",
  ];

  String selectedCategory = "Best Practices";

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          /// MODULE HEADER
          const ModuleHeaderWidget(
            title: "Knowledge Link",
            subtitle:
                "Guides • Articles • AI Extension • News • Forums",
            trailingIcon: Icons.auto_awesome_outlined,
          ),

          const SizedBox(height: 18),

          /// QUICK ACCESS BLOCKS
          const KnowledgeQuickAccessWidget(),

          const SizedBox(height: 20),

          /// CATEGORY SWITCHER
          KnowledgeCategoryChipsWidget(
            categories: categories,
            selectedCategory: selectedCategory,
            onCategorySelected: (value) {
              setState(() {
                selectedCategory = value;
              });
            },
          ),

          const SizedBox(height: 24),

          /// GUIDES (resolved from the backend)
          const KnowledgeBrowseGuidesWidget(),

          const SizedBox(height: 24),

          /// FORUM PLACEHOLDER
          const SectionHeaderWidget(
            title: "Community Forum",
          ),

          const SizedBox(height: 12),

          const EmptyStateCardWidget(
            icon: Icons.forum_outlined,
            title: "Farmer Discussions",
            subtitle:
                "Community forums and expert discussions will appear here",
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
