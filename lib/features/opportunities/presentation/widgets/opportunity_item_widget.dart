import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/section_container_widget.dart';

class OpportunityItemWidget extends StatelessWidget {
  final String title;
  final String type;
  final String amount;
  final String deadline;
  final Color primary;

  const OpportunityItemWidget({
    super.key,
    required this.title,
    required this.type,
    required this.amount,
    required this.deadline,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      child: Row(
        children: [
          /// LEFT CONTENT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          /// RIGHT DATA BLOCK
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: primary,
                  ),
                ),
                Text(
                  deadline,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}