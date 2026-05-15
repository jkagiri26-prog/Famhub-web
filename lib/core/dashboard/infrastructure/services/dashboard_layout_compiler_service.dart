import '../../domain/models/dashboard_descriptor.dart';
import 'dashboard_usage_tracker.dart';

/// ============================================================
/// DASHBOARD LAYOUT COMPILER (UNIFIED STRATEGY ENGINE)
/// ============================================================
///
/// Replaces:
/// - LayoutCompiler
/// - LayoutOptimizer
///
/// Now supports:
/// - deterministic ordering
/// - usage-aware optimization
/// - stable tie-breaking
/// ============================================================

enum DashboardCompileMode {
  stable,
  optimized,
}

class DashboardLayoutCompiler {
  final DashboardUsageTracker? usageTracker;
  final DashboardCompileMode mode;

  DashboardLayoutCompiler({
    this.usageTracker,
    this.mode = DashboardCompileMode.stable,
  });

  List<DashboardDescriptor> compile(
    List<DashboardDescriptor> descriptors,
  ) {
    final list = List<DashboardDescriptor>.from(descriptors);

    switch (mode) {
      case DashboardCompileMode.optimized:
        return _optimizedSort(list);

      case DashboardCompileMode.stable:
      default:
        return _stableSort(list);
    }
  }

  /// ============================================================
  /// STABLE MODE (backend deterministic ordering)
  /// ============================================================
  List<DashboardDescriptor> _stableSort(
    List<DashboardDescriptor> list,
  ) {
    list.sort((a, b) {
      final order = a.displayOrder.compareTo(b.displayOrder);
      if (order != 0) return order;

      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) return priority;

      return a.widgetKey.compareTo(b.widgetKey); // ⚡ stable tie-breaker
    });

    return list;
  }

  /// ============================================================
  /// OPTIMIZED MODE (usage-aware ordering)
  /// ============================================================
  List<DashboardDescriptor> _optimizedSort(
    List<DashboardDescriptor> list,
  ) {
    if (usageTracker == null) {
      return _stableSort(list);
    }

    list.sort((a, b) {
      final aScore =
          usageTracker!.score(a.widgetKey) + a.priority;

      final bScore =
          usageTracker!.score(b.widgetKey) + b.priority;

      final cmp = bScore.compareTo(aScore);
      if (cmp != 0) return cmp;

      // ⚡ stable fallback to avoid flicker
      return a.widgetKey.compareTo(b.widgetKey);
    });

    return list;
  }
}