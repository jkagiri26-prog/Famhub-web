import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Wrap(
        spacing: 8,
        children: [
          ElevatedButton(onPressed: () {}, child: const Text("Add Listing")),
          ElevatedButton(onPressed: () {}, child: const Text("View Market")),
        ],
      ),
    );
  }
}