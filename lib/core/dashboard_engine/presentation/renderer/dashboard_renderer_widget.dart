import 'package:flutter/widgets.dart';

import 'package:famhub_app/core/dashboard_engine/application/composition/composition_snapshot.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/composition_node.dart';

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

    /// ============================================================
    /// PURE RENDERING ONLY (NO GROUPING LOGIC)
    /// ============================================================
    return Column(
      children: nodes.map(builder).toList(),
    );
  }
}