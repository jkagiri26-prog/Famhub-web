import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';

import 'package:famhub_app/features/carbon_credit/presentation/widgets/carbon_tab_bar_widget.dart';
import '../widgets/carbon_tab_views_widget.dart';

class CarbonCreditPage extends StatelessWidget {
  const CarbonCreditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 4,
      child: ResponsiveWrapper(
        child: Column(
          children: [
            SizedBox(height: 12),

            /// Shared Header Widget
            ModuleHeaderWidget(
              title: 'Carbon Portal',
              subtitle:
                  'Carbon Credits • Calculator • Market • Community',
              trailingIcon: Icons.eco_outlined,
            ),

            SizedBox(height: 16),

            /// Module-specific Tabs
            CarbonCreditTabBarWidget(),

            SizedBox(height: 20),

            /// Module-specific Tab Views
            Expanded(
              child: CarbonCreditTabViewsWidget(),
            ),
          ],
        ),
      ),
    );
  }
}