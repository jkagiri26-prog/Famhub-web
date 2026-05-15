import '../../domain/models/dashboard_descriptor.dart';

class DashboardDiffResult {
  final List<DashboardDescriptor> added;
  final List<DashboardDescriptor> removed;
  final List<DashboardDescriptor> updated;
  final List<DashboardDescriptor> unchanged;

  /// ⚡ FAST LOOKUP SETS (critical for renderer performance)
  final Set<String> addedIds;
  final Set<String> removedIds;
  final Set<String> updatedIds;
  final Set<String> unchangedIds;

  const DashboardDiffResult({
    required this.added,
    required this.removed,
    required this.updated,
    required this.unchanged,
    required this.addedIds,
    required this.removedIds,
    required this.updatedIds,
    required this.unchangedIds,
  });

  /// ⚡ FACTORY HELPERS (build sets automatically)
  factory DashboardDiffResult.from({
    required List<DashboardDescriptor> added,
    required List<DashboardDescriptor> removed,
    required List<DashboardDescriptor> updated,
    required List<DashboardDescriptor> unchanged,
  }) {
    return DashboardDiffResult(
      added: added,
      removed: removed,
      updated: updated,
      unchanged: unchanged,

      addedIds: added.map((e) => e.id).toSet(),
      removedIds: removed.map((e) => e.id).toSet(),
      updatedIds: updated.map((e) => e.id).toSet(),
      unchangedIds: unchanged.map((e) => e.id).toSet(),
    );
  }

  /// ⚡ QUICK CHECK HELPERS (used by renderer)
  bool isRemoved(String id) => removedIds.contains(id);
  bool isUpdated(String id) => updatedIds.contains(id);
  bool isAdded(String id) => addedIds.contains(id);
}