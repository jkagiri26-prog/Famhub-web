import '../../domain/models/composition_node.dart';
import '../../domain/models/layout_context.dart';
import 'composition_snapshot.dart';

class DashboardCompositionEngine {
  final LayoutResolver layoutResolver;

  DashboardCompositionEngine({
    required this.layoutResolver,
  });

  /// ============================================================
  /// COMPOSITION BUILD PIPELINE (STRUCTURE ONLY)
  /// ============================================================
  Future<CompositionSnapshot> build({
    required LayoutContext context,
    required List<DashboardModuleDefinition> modules,
  }) async {
    final nodes = <CompositionNode>[];

    /// Resolve layout ONCE (device + structure only)
    final layoutDecision = layoutResolver.resolve(
      context: context,
    );

    for (final module in modules) {
      nodes.add(
        CompositionNode(
          id: '${module.moduleKey}_${module.widgetKey}',
          moduleKey: module.moduleKey,
          widgetKey: module.widgetKey,

          /// ✅ FIX: zone is NOT layout type
          /// zone is structural placeholder ONLY here
          zone: _resolveBaseZone(module),

          /// deterministic ordering
          order: _deriveOrder(module),
        ),
      );
    }

    nodes.sort((a, b) => a.order.compareTo(b.order));

    return CompositionSnapshot(
      nodes: nodes,
      generatedAt: DateTime.now(),
    );
  }

  /// ============================================================
  /// ZONE RESOLUTION (SAFE DEFAULT ONLY)
  /// ============================================================
  String _resolveBaseZone(
    DashboardModuleDefinition module,
  ) {
    /// IMPORTANT:
    /// This is ONLY fallback.
    /// Real zone assignment happens in Zone Mapping Engine.
    return 'main';
  }

  /// ============================================================
  /// INTERNAL ORDER DERIVATION (STABLE)
  /// ============================================================
  int _deriveOrder(DashboardModuleDefinition module) {
    return module.moduleKey.hashCode +
        module.widgetKey.hashCode;
  }
}