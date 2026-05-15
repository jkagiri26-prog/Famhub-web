import 'package:flutter/material.dart';

import 'overview_tab_widget.dart';
import 'calculator_tab_widget.dart';
import 'marketplace_tab_widget.dart';
import 'community_tab_widget.dart';

class CarbonCreditTabViewsWidget extends StatelessWidget {
  const CarbonCreditTabViewsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabBarView(
      children: [
        OverviewTabWidget(),
        CalculatorTabWidget(),
        MarketplaceTabWidget(),
        CommunityTabWidget(),
      ],
    );
  }
}