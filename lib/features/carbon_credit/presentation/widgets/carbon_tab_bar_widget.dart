import 'package:flutter/material.dart';

class CarbonCreditTabBarWidget extends StatelessWidget {
  const CarbonCreditTabBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(text: 'Overview'),
        Tab(text: 'Calculate'),
        Tab(text: 'Market'),
        Tab(text: 'Village Impact'),
      ],
    );
  }
}