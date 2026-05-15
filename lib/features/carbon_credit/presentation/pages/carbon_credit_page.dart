import 'package:flutter/material.dart';

import '../../../../shared/layout/responsive_wrapper_widget.dart';
import '../../../../shared/widgets/headers/module_header_widget.dart';

import '../widgets/carbon_credit_tab_bar_widget.dart';
import '../widgets/carbon_credit_tab_views_widget.dart';

class CarbonCreditPage extends StatelessWidget {
  const CarbonCreditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: ResponsiveWrapperWidget(
        child: Column(
          children: const [
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