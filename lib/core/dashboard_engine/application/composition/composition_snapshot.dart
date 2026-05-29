import '../../domain/models/composition_node.dart';

/// ============================================================
/// COMPOSITION SNAPSHOT (APPLICATION OUTPUT)
/// ============================================================
///
/// Immutable output of DashboardCompositionEngine.
///
/// This is the single source of truth for rendering.
///
/// Used for:
/// - diff engine
/// - renderer
/// - caching
/// ============================================================
class CompositionSnapshot {
  final List<CompositionNode> nodes;
  final DateTime generatedAt;

  /// Fast lookup index (id → node)
  final Map<String, CompositionNode> index;

  /// Zone grouping cache (zone → nodes)
  final Map<String, List<CompositionNode>> zoneIndex;

  const CompositionSnapshot({
    required this.nodes,
    required this.generatedAt,
    required this.index,
    required this.zoneIndex,
  });

  /// ============================================================
  /// EMPTY STATE
  /// ============================================================
  factory CompositionSnapshot.empty() {
    return CompositionSnapshot(
      nodes: const [],
      generatedAt: DateTime.now(),
      index: const {},
      zoneIndex: const {},
    );
  }

  /// ============================================================
  /// BUILDER (SAFE CONSTRUCTION)
  /// ============================================================
  factory CompositionSnapshot.fromNodes(
    List<CompositionNode> nodes,
  ) {
    final index = <String, CompositionNode>{};
    final zoneIndex = <String, List<CompositionNode>>{};

    for (final node in nodes) {
      index[node.id] = node;

      zoneIndex.putIfAbsent(node.zone, () => []);
      zoneIndex[node.zone]!.add(node);
    }

    return CompositionSnapshot(
      nodes: List.unmodifiable(nodes),
      generatedAt: DateTime.now(),
      index: Map.unmodifiable(index),
      zoneIndex: Map.unmodifiable(zoneIndex),
    );
  }

  /// ============================================================
  /// FAST ACCESS HELPERS
  /// ============================================================
  bool get isEmpty => nodes.isEmpty;
  bool get hasNodes => nodes.isNotEmpty;

  CompositionNode? getById(String id) => index[id];

  List<CompositionNode> getByZone(String zone) =>
      zoneIndex[zone] ?? const [];
}