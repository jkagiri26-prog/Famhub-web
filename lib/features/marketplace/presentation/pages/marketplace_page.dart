import 'package:flutter/material.dart';

import '../../../../shared/widgets/layout/responsive_wrapper_widget.dart';
import '../../../../shared/widgets/headers/module_header_widget.dart';
import '../../../../shared/widgets/headers/section_header_widget.dart';

import '../widgets/marketplace_filter_tabs_widget.dart';
import '../widgets/marketplace_featured_section_widget.dart';
import '../widgets/subcategory_island_widget.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  String activeTab = 'ALL';

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapperWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          ModuleHeaderWidget(
            title: 'Marketplace',
            subtitle: 'Buy ? Sell ? Inputs ? Livestock ? Produce',
            trailingIcon: Icons.add_circle_outline,
            onTrailingTap: () {},
          ),

          const SizedBox(height: 16),

          MarketplaceFilterTabsWidget(
            activeTab: activeTab,
            onChanged: (value) {
              setState(() {
                activeTab = value;
              });
            },
          ),

          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                const MarketplaceFeaturedSectionWidget(),

                const SizedBox(height: 20),

                if (activeTab == 'ALL' || activeTab == 'LIVESTOCK')
                  const SubcategoryIslandWidget(
                    title: 'LIVESTOCK',
                  ),

                if (activeTab == 'ALL' || activeTab == 'CROPS')
                  const SubcategoryIslandWidget(
                    title: 'CROPS & PRODUCE',
                  ),

                if (activeTab == 'ALL' || activeTab == 'INPUTS')
                  const SubcategoryIslandWidget(
                    title: 'FARM INPUTS',
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}