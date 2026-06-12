import 'package:flutter/material.dart';

class ActivityFeed extends StatelessWidget {
  const ActivityFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Column(
        children: [
          ListTile(title: Text("Recent Activity")),
          ListTile(
            title: Text('No recent activities to display.'),
          ),
        ],
      ),
    );
  }
}