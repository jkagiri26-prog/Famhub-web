import 'package:flutter/material.dart';

import 'package:famhub_app/core/dashboard_engine/application/composition/composition_snapshot.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/composition_node.dart';

class DashboardRendererService {
  const DashboardRendererService();

  Widget render({
    required CompositionSnapshot snapshot,
    Widget Function(CompositionNode node)? nodeBuilder,
  }) {
    final nodes = snapshot.nodes;

    return Column(
      children: nodes.map((node) {
        return nodeBuilder != null
            ? nodeBuilder(node)
            : _DefaultNodeRenderer(node: node);
      }).toList(),
    );
  }
}

/// ============================================================
/// DEFAULT NODE RENDERER (SAFE FALLBACK ONLY)
/// ============================================================
class _DefaultNodeRenderer extends StatelessWidget {
  final CompositionNode node;

  const _DefaultNodeRenderer({
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${node.moduleKey} → ${node.widgetKey}',
      ),
    );
  }
}