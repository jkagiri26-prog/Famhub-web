import 'package:flutter/material.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/layouts/section_container_widget.dart';
import '../widgets/featured_opportunity_widget.dart';
import '../widgets/opportunity_item_widget.dart';

/// FAMHUB Module: OpportunitiesPage
/// Fully aligned with Shared Widget System
/// - ResponsiveWrapper
/// - ModuleHeaderWidget
/// - SectionHeaderWidget
/// - SectionContainerWidget
class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          /// MODULE HEADER
          ModuleHeaderWidget(
            title: "Agri-Opportunities",
            subtitle: "Tenders • Grants • Training • Funding",
            trailingIcon: Icons.rocket_launch_outlined,
            onTrailingTap: () {},
          ),

          const SizedBox(height: 16),

          /// FEATURED SECTION
          const FeaturedOpportunityWidget(),

          const SizedBox(height: 20),

          /// SECTION HEADER
          const SectionHeaderWidget(
            title: "Latest Listings",
          ),

          const SizedBox(height: 12),

          /// LIST ITEMS
          OpportunityItemWidget(
            title: "World Bank Smallholder Grant",
            type: "GRANT",
            amount: "KSh 50,000",
            deadline: "2 Days Left",
            primary: primary,
          ),

          const SizedBox(height: 12),

          OpportunityItemWidget(
            title: "County Fertilizer Distribution",
            type: "TENDER",
            amount: "KSh 2.4M",
            deadline: "Feb 15",
            primary: primary,
          ),

          const SizedBox(height: 12),

          OpportunityItemWidget(
            title: "Youth in Ag Training",
            type: "TRAINING",
            amount: "FREE",
            deadline: "Open",
            primary: primary,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
