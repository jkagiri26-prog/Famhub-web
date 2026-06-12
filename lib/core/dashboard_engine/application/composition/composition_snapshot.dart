import 'package:famhub_app/core/dashboard_engine/domain/models/composition_node.dart';

/// ============================================================
/// COMPOSITION SNAPSHOT (APPLICATION OUTPUT)
/// ============================================================
///
/// Immutable, deterministic representation of UI structure.
///
/// This is the SINGLE source of truth for:
/// - rendering
/// - diffing
/// - caching
///
/// It must NOT contain:
/// ❌ layout logic
/// ❌ zone intelligence
/// ❌ module resolution
/// ============================================================
class CompositionSnapshot {
  final List<CompositionNode> nodes;
  final DateTime generatedAt;

  /// Fast lookup index (id → node)
  final Map<String, CompositionNode> index;

  /// ============================================================
  /// NOTE:
  /// zoneIndex is retained ONLY as a rendering optimization layer.
  /// It is NOT part of system logic.
  /// ============================================================
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
  /// SAFE BUILD FROM NODES (DETERMINISTIC)
  /// ============================================================
  factory CompositionSnapshot.fromNodes(
    List<CompositionNode> nodes,
  ) {
    final sortedNodes = List<CompositionNode>.from(nodes)
      ..sort((a, b) => a.order.compareTo(b.order));

    final index = <String, CompositionNode>{};
    final zoneIndex = <String, List<CompositionNode>>{};

    for (final node in sortedNodes) {
      index[node.id] = node;

      zoneIndex.putIfAbsent(node.zone, () => <CompositionNode>[]);
      zoneIndex[node.zone]!.add(node);
    }

    return CompositionSnapshot(
      nodes: List.unmodifiable(sortedNodes),
      generatedAt: DateTime.now(),
      index: Map.unmodifiable(index),
      zoneIndex: Map.unmodifiable(
        zoneIndex.map(
          (k, v) => MapEntry(k, List.unmodifiable(v)),
        ),
      ),
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