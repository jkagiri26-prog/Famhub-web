import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import '../widgets/expert_card_widget.dart';
import '../widgets/service_category_card_widget.dart';

class ExtensionServicesPage extends StatelessWidget {
  const ExtensionServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveWrapper(
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// MODULE HEADER
            ModuleHeaderWidget(
              title: 'Extension Services',
              subtitle:
                  'Expert advice • Field support • Agricultural guidance',
              trailingIcon: Icons.support_agent_outlined,
            ),

            SizedBox(height: 20),

            /// SECTION HEADER
            SectionHeaderWidget(
              title: 'Available Support Areas',
            ),

            SizedBox(height: 12),

            /// SERVICE CATEGORIES
            ServiceCategoryCardWidget(
              title: 'Crop Advisory',
              description:
                  'Get expert recommendations on planting, pests, diseases, and crop productivity.',
              icon: Icons.grass_outlined,
            ),

            SizedBox(height: 12),

            ServiceCategoryCardWidget(
              title: 'Livestock Support',
              description:
                  'Veterinary guidance, feeding plans, breeding, and herd productivity.',
              icon: Icons.pets_outlined,
            ),

            SizedBox(height: 24),

            /// SECTION HEADER
            SectionHeaderWidget(
              title: 'Available Experts',
            ),

            SizedBox(height: 12),

            /// EXPERT CARDS
            ExpertCardWidget(
              name: "Dr. Jane Kamau",
              specialty: "Soil Science & Fertility",
              status: "Online",
              imageUrl:
                  "https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?w=200",
            ),

            SizedBox(height: 12),

            ExpertCardWidget(
              name: "Officer Samuel Otieno",
              specialty: "Livestock Management",
              status: "In Field",
              imageUrl:
                  "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=200",
            ),

            SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
