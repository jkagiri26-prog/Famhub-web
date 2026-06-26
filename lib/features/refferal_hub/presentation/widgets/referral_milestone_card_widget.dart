import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/section_container_widget.dart';

class ReferralMilestoneCardWidget extends StatelessWidget {
  const ReferralMilestoneCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionContainerWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Silver Milestone (12/15)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: 0.8,
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}
