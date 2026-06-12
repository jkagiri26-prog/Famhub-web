import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';

import '../widgets/marketplace_filter_tabs_widget.dart';
import '../widgets/marketplace_featured_section_widget.dart';
import '../widgets/subcategory_island_widget.dart';
import '../../application/providers/marketplace_provider.dart';

/// Active tab state — kept simple as a local provider.
final _activeTabProvider = StateProvider<String>((ref) => 'ALL');

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  @override
  void initState() {
    super.initState();
        // Trigger initial load via ref.invalidate (auto-builds)
    ref.invalidate(marketplaceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(_activeTabProvider);
    final listingsAsync = ref.watch(marketplaceProvider);

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
              ref.read(_activeTabProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                const MarketplaceFeaturedSectionWidget(),

                const SizedBox(height: 20),

                // Show listing count from provider
                if (listingsAsync is AsyncData && listingsAsync.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      '${listingsAsync.value.length} listings available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

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