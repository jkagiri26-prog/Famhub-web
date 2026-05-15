import '../../domain/models/dashboard_descriptor.dart';
import '../../domain/models/dashboard_diff_result.dart';

class DashboardDiffEngine {
  DashboardDiffResult diff(
    List<DashboardDescriptor> oldList,
    List<DashboardDescriptor> newList,
  ) {
    final oldMap = {for (final e in oldList) e.id: e};
    final newMap = {for (final e in newList) e.id: e};

    final added = <DashboardDescriptor>[];
    final removed = <DashboardDescriptor>[];
    final updated = <DashboardDescriptor>[];
    final unchanged = <DashboardDescriptor>[];

    for (final newItem in newList) {
      final oldItem = oldMap[newItem.id];

      if (oldItem == null) {
        added.add(newItem);
        continue;
      }

      if (_isDifferent(oldItem, newItem)) {
        updated.add(newItem);
      } else {
        unchanged.add(newItem);
      }
    }

    for (final oldItem in oldList) {
      if (!newMap.containsKey(oldItem.id)) {
        removed.add(oldItem);
      }
    }

    return DashboardDiffResult.from(
      added: added,
      removed: removed,
      updated: updated,
      unchanged: unchanged,
    );
  }

  /// ============================================================
  /// SMART COMPARISON (renderer-aware diff logic)
  /// ============================================================
  bool _isDifferent(
    DashboardDescriptor a,
    DashboardDescriptor b,
  ) {
    return a.config != b.config ||
        a.displayOrder != b.displayOrder ||
        a.priority != b.priority ||
        a.layoutZone != b.layoutZone ||
        a.isEnabled != b.isEnabled ||
        a.visibilityScope != b.visibilityScope ||
        a.cacheStrategy != b.cacheStrategy;
  }
}