import 'package:flutter/material.dart';

import '../../../../shared/widgets/cards/report_card_widget.dart';
import '../../../../shared/widgets/headers/section_header_widget.dart';

class MarketplaceTabWidget extends StatelessWidget {
  const MarketplaceTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: const [
        SectionHeaderWidget(
          title: 'Available Carbon Reports',
        ),

        SizedBox(height: 12),

        ReportCardWidget(
          title: 'Carbon Credit Market Report',
          subtitle: 'Premium Market Analysis',
          price: 'KSh 350',
          isLocked: true,
        ),

        SizedBox(height: 80),
      ],
    );
  }
}