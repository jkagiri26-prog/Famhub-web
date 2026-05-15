import 'package:flutter/material.dart';

class DashboardLoader extends StatelessWidget {
  const DashboardLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}