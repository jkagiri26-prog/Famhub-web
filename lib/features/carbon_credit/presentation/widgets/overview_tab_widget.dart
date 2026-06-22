import 'package:flutter/material.dart';

import 'package:famhub_app/shared/widgets/cards/stats_card_widget.dart';
import '../../../../shared/widgets/headers/section_header_widget.dart';

class OverviewTabWidget extends StatelessWidget {
  const OverviewTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
        return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        SectionHeaderWidget(
          title: 'Carbon Summary',
        ),

        SizedBox(height: 12),

        StatsCard(
          title: 'Credits Earned',
          value: '245',
          icon: Icons.eco_outlined,
        ),

        SizedBox(height: 12),

        StatsCard(
          title: 'Estimated Value',
          value: 'KSh 18,500',
          icon: Icons.payments_outlined,
        ),

        SizedBox(height: 80),
      ],
    );
  }
}