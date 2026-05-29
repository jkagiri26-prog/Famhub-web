import 'package:flutter/widgets.dart';

import '../../application/composition/composition_snapshot.dart';
import '../../domain/models/composition_node.dart';

/// ============================================================
/// DASHBOARD RENDERER WIDGET
/// ============================================================
///
/// Responsible ONLY for rendering CompositionSnapshot nodes
/// into UI widgets.
///
/// ❌ NOT responsible for:
/// - layout decisions
/// - ordering logic
/// - composition rules
/// ============================================================
class DashboardRendererWidget extends StatelessWidget {
  final CompositionSnapshot snapshot;
  final Widget Function(CompositionNode node) builder;

  const DashboardRendererWidget({
    super.key,
    required this.snapshot,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final nodes = snapshot.nodes;

    // ============================================================
    // GROUP BY ZONE (PRESERVE COMPOSITION STRUCTURE)
    // ============================================================
    final grouped = <String, List<CompositionNode>>{};

    for (final node in nodes) {
      grouped.putIfAbsent(node.zone, () => []).add(node);
    }

    // Sort nodes inside each group
    for (final entry in grouped.entries) {
      entry.value.sort(
        (a, b) => a.order.compareTo(b.order),
      );
    }

    return Column(
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entry.value.map(builder).toList(),
        );
      }).toList(),
    );
  }
}