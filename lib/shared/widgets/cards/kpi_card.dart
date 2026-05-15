import 'package:flutter/material.dart';

class KPICard extends StatelessWidget {
  const KPICard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        title: Text("Total Sales"),
        subtitle: Text("KES 120,000"),
      ),
    );
  }
}