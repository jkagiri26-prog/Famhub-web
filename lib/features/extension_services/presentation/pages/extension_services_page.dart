import 'package:flutter/material.dart';

import 'package:famhub_app/features/extension_services/presentation/widgets/service_category_card_widget.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';

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
              subtitle: 'Practical advice for your crops and livestock',
              trailingIcon: Icons.support_agent_outlined,
            ),

            SizedBox(height: 20),

            /// AREAS THIS MODULE COVERS
            SectionHeaderWidget(title: 'This can help with'),

            SizedBox(height: 12),

            ServiceCategoryCardWidget(
              title: 'Crop Advisory',
              description:
                  'Planting, pests, diseases, and crop productivity questions.',
              icon: Icons.grass_outlined,
            ),

            SizedBox(height: 12),

            ServiceCategoryCardWidget(
              title: 'Livestock Support',
              description:
                  'Feeding, breeding, and general herd or flock questions.',
              icon: Icons.pets_outlined,
            ),

            SizedBox(height: 24),

            /// HUMAN HELP — plain text only. FAMHUB does not hold a directory
            /// of extension providers, so no referral is offered here.
            SectionHeaderWidget(title: 'When you need a person'),

            SizedBox(height: 8),

            Text(
              'Extension advice helps you think a problem through, but it is '
              'not a substitute for a qualified professional.\n\n'
              'For severe or fast-worsening animal illness, suspected '
              'poisoning, difficult births, or a heavy crop outbreak, contact '
              'a county extension officer, KALRO, or a qualified veterinary '
              'officer promptly.\n\n'
              'FAMHUB does not currently hold a directory of extension '
              'providers, so it cannot contact or book anyone on your behalf.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),

            SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
