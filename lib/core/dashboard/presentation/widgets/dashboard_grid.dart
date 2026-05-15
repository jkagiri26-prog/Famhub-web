import 'package:flutter/material.dart';

class DashboardGrid extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double spacing;

  const DashboardGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        return children[index];
      },
    );
  }
}