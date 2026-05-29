import '../../domain/models/composition_node.dart';
import 'composition_snapshot.dart';

/// ============================================================
/// SNAPSHOT DIFF (PERFORMANCE-CRITICAL ENGINE LAYER)
/// ============================================================
///
/// Computes differences between two CompositionSnapshots.
///
/// Tracks:
/// - added nodes
/// - removed nodes
/// - updated nodes (structure changes)
/// - unchanged nodes
///
/// Optimized for renderer incremental updates.
/// ============================================================
class SnapshotDiff {
  final List<CompositionNode> added;
  final List<CompositionNode> removed;
  final List<CompositionNode> updated;
  final List<CompositionNode> unchanged;

  final Set<String> addedIds;
  final Set<String> removedIds;
  final Set<String> updatedIds;
  final Set<String> unchangedIds;

  const SnapshotDiff({
    required this.added,
    required this.removed,
    required this.updated,
    required this.unchanged,
    required this.addedIds,
    required this.removedIds,
    required this.updatedIds,
    required this.unchangedIds,
  });

  /// ============================================================
  /// O(n) DIFF COMPUTATION
  /// ============================================================
  factory SnapshotDiff.calculate({
    required CompositionSnapshot oldSnapshot,
    required CompositionSnapshot newSnapshot,
  }) {
    final oldIndex = oldSnapshot.index;
    final newIndex = newSnapshot.index;

    final added = <CompositionNode>[];
    final removed = <CompositionNode>[];
    final updated = <CompositionNode>[];
    final unchanged = <CompositionNode>[];

    final addedIds = <String>{};
    final removedIds = <String>{};
    final updatedIds = <String>{};
    final unchangedIds = <String>{};

    for (final entry in newIndex.entries) {
      final id = entry.key;
      final newNode = entry.value;
      final oldNode = oldIndex[id];

      if (oldNode == null) {
        added.add(newNode);
        addedIds.add(id);
      } else if (_isDifferent(oldNode, newNode)) {
        updated.add(newNode);
        updatedIds.add(id);
      } else {
        unchanged.add(newNode);
        unchangedIds.add(id);
      }
    }

    for (final entry in oldIndex.entries) {
      final id = entry.key;

      if (!newIndex.containsKey(id)) {
        removed.add(entry.value);
        removedIds.add(id);
      }
    }

    return SnapshotDiff(
      added: List.unmodifiable(added),
      removed: List.unmodifiable(removed),
      updated: List.unmodifiable(updated),
      unchanged: List.unmodifiable(unchanged),
      addedIds: addedIds,
      removedIds: removedIds,
      updatedIds: updatedIds,
      unchangedIds: unchangedIds,
    );
  }

  /// ============================================================
  /// STRUCTURAL DIFFERENCE CHECK
  /// ============================================================
  static bool _isDifferent(
    CompositionNode oldNode,
    CompositionNode newNode,
  ) {
    return oldNode.zone != newNode.zone ||
        oldNode.order != newNode.order ||
        oldNode.widgetKey != newNode.widgetKey;
  }

  bool wasAdded(String id) => addedIds.contains(id);
  bool wasRemoved(String id) => removedIds.contains(id);
  bool wasUpdated(String id) => updatedIds.contains(id);
  bool isUnchanged(String id) => unchangedIds.contains(id);

  bool get hasChanges =>
      addedIds.isNotEmpty ||
      removedIds.isNotEmpty ||
      updatedIds.isNotEmpty;
}