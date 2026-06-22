import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/section_container_widget.dart';

class FeaturedOpportunityWidget extends StatelessWidget {
  const FeaturedOpportunityWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF002E28),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "NEW FUNDING",
              style: TextStyle(
                color: Color(0xFFC6FF00),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Dairy Modernization\nFund (2026)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "LPOs now accepted for hardware financing.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}