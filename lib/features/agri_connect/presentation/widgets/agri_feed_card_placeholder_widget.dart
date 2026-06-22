import 'package:flutter/material.dart';
import 'package:famhub_app/shared/layouts/section_container_widget.dart';

class AgriFeedCardPlaceholderWidget extends StatelessWidget {
  final String title;
  final String subtitle;

  const AgriFeedCardPlaceholderWidget({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 10,
            color: Colors.grey.shade300,
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            height: 10,
            color: Colors.grey.shade200,
          ),

          const SizedBox(height: 6),

          Container(
            width: 200,
            height: 10,
            color: Colors.grey.shade200,
          ),
        ],
      ),
    );
  }
}