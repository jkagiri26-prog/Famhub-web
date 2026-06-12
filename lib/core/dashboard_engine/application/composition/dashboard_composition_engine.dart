import 'package:flutter/foundation.dart';
import 'package:famhub_app/core/modules/domain/models/dashboard_module_definition.dart';

import 'package:famhub_app/core/dashboard_engine/domain/models/composition_node.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/layout_context.dart';
import 'package:famhub_app/core/dashboard_engine/application/resolution/layout_resolver.dart';
import 'package:famhub_app/core/dashboard_engine/application/composition/composition_snapshot.dart';

class DashboardCompositionEngine {
  final LayoutResolver layoutResolver;

  DashboardCompositionEngine({
    LayoutResolver? layoutResolver,
  }) : layoutResolver = layoutResolver ?? const LayoutResolver();

  /// ============================================================
  /// COMPOSITION BUILD PIPELINE (STRUCTURE ONLY)
  /// ============================================================
  Future<CompositionSnapshot> build({
    required LayoutContext context,
    required List<DashboardModuleDefinition> modules,
  }) async {
    /// Resolve layout once (UI hint only, NOT structure)
    final layoutDecision = layoutResolver.resolve(
      context: context,
    );

    final nodes = <CompositionNode>[];

    for (final module in modules) {
      nodes.add(
        CompositionNode(
          id: '${module.moduleKey}_${module.widgetKey}',
          moduleKey: module.moduleKey,
          widgetKey: module.widgetKey,

          /// ❌ NO ZONES ANYMORE
          /// instead we keep flat structure
          order: _deriveOrder(module),

          /// optional: layout hints only (safe metadata)
          payload: {
            'layoutHint': layoutDecision.preset.type.toString(),
          },
        ),
      );
    }

    nodes.sort((a, b) => a.order.compareTo(b.order));

    return CompositionSnapshot.fromNodes(nodes);
  }

  /// ============================================================
  /// INTERNAL ORDER DERIVATION (STABLE)
  /// ============================================================
  int _deriveOrder(DashboardModuleDefinition module) {
    return module.moduleKey.hashCode +
        module.widgetKey.hashCode;
  }
}