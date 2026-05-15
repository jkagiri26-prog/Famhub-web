import 'package:flutter/material.dart';

class FarmAlertsWidget extends StatelessWidget {
  const FarmAlertsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Farm Alerts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text('No active alerts right now.'),
          ],
        ),
      ),
    );
  }
}

