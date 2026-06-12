import 'package:famhub_app/core/dashboard_engine/application/composition/composition_snapshot.dart';

/// ============================================================
/// COMPOSITION CACHE (IN-FLIGHT PERFORMANCE LAYER)
/// ============================================================
///
/// Stores last computed CompositionSnapshot to avoid redundant
/// recomposition and diff recalculation.
///
/// ❌ NOT a state manager
/// ❌ NOT persistent storage
/// ❌ NOT multi-session aware
/// ============================================================
class CompositionCache {
  CompositionSnapshot? _snapshot;

  /// Get last cached snapshot
  CompositionSnapshot? get snapshot => _snapshot;

  /// Save latest snapshot (overwrites previous)
  void save(CompositionSnapshot snapshot) {
    _snapshot = snapshot;
  }

  /// Clear cache (used on full invalidation events)
  void clear() {
    _snapshot = null;
  }

  /// ============================================================
  /// SAFETY HELPERS
  /// ============================================================

  bool get hasSnapshot => _snapshot != null;

  bool get isEmpty => _snapshot == null;
}