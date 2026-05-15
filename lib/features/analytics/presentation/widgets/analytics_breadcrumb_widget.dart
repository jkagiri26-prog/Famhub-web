import 'package:flutter/material.dart';

class AnalyticsBreadcrumbWidget extends StatelessWidget {
  const AnalyticsBreadcrumbWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.location_on, size: 14, color: Colors.green),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            "Kenya > Rift Valley > Nakuru",
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}