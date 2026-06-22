// ignore: dangling_library_doc_comments
/// ============================================================
/// ADAPTIVE CONTENT GRID (REUSABLE RESPONSIVE GRID)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/layouts/ = reusable layout primitives
///
/// ✅ Responsibilities:
///   - Responsive grid that adapts columns to screen width
///   - Consistent spacing across all modules
///   - Reusable across dashboard and feature pages
///
/// ❌ Does NOT:
///   - Reference registry, services, or providers
///   - Contain business logic
/// ============================================================

import 'package:flutter/material.dart';

class AdaptiveContentGrid extends StatelessWidget {
  final List<Widget> items;
  final double spacing;
  final double runSpacing;
  final double? childAspectRatio;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  const AdaptiveContentGrid({
    super.key,
    required this.items,
    this.spacing = 12.0,
    this.runSpacing = 12.0,
    this.childAspectRatio,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _resolveColumnCount(constraints.maxWidth);

        if (childAspectRatio != null) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: runSpacing,
              childAspectRatio: childAspectRatio!,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => items[index],
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: items.map((item) {
            return SizedBox(
              width: _resolveItemWidth(constraints.maxWidth, crossAxisCount),
              child: item,
            );
          }).toList(),
        );
      },
    );
  }

  int _resolveColumnCount(double maxWidth) {
    if (maxWidth > 900) return desktopColumns ?? 3;
    if (maxWidth > 600) return tabletColumns ?? 2;
    return mobileColumns ?? 1;
  }

  double _resolveItemWidth(double maxWidth, int columns) {
    final totalSpacing = spacing * (columns - 1);
    return (maxWidth - totalSpacing) / columns;
  }
}
