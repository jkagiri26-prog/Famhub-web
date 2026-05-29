import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ============================================================
/// ZONE INVALIDATION TYPES (CLEAR SEMANTICS)
/// ============================================================
enum ZoneSignalType {
  refresh,
  remove,
  invalidate,
  navigation,
}

/// ============================================================
/// ZONE CONTROLLER
/// ============================================================
class DashboardZoneController
    extends StateNotifier<Map<String, ZoneSignalType>> {
  DashboardZoneController() : super({});

  /// ============================================================
  /// REFRESH ZONE
  /// ============================================================
  void refreshZone(String zoneId) {
    _set(zoneId, ZoneSignalType.refresh);
  }

  /// ============================================================
  /// REMOVE WIDGET
  /// ============================================================
  void removeWidget(String widgetId) {
    _set(widgetId, ZoneSignalType.remove);
  }

  /// ============================================================
  /// NAVIGATION REFRESH
  /// ============================================================
  void refreshNavigation() {
    _set('navigation', ZoneSignalType.navigation);
  }

  /// ============================================================
  /// INVALIDATE WIDGET
  /// ============================================================
  void invalidateWidget(String widgetId) {
    _set(widgetId, ZoneSignalType.invalidate);
  }

  /// ============================================================
  /// INTERNAL SETTER (CENTRALIZED UPDATE LOGIC)
  /// ============================================================
  void _set(String key, ZoneSignalType type) {
    state = {
      ...state,
      key: type,
    };
  }

  /// ============================================================
  /// RESET AFTER CONSUMPTION
  /// ============================================================
  void reset(String key) {
    final updated = Map<String, ZoneSignalType>.from(state);
    updated.remove(key);
    state = updated;
  }

  /// ============================================================
  /// BATCH RESET (IMPORTANT FOR COALESCED EXECUTION)
  /// ============================================================
  void resetBatch(List<String> keys) {
    final updated = Map<String, ZoneSignalType>.from(state);

    for (final key in keys) {
      updated.remove(key);
    }

    state = updated;
  }
}

/// ============================================================
/// PROVIDER
/// ============================================================
final dashboardZoneControllerProvider =
    StateNotifierProvider<DashboardZoneController,
        Map<String, ZoneSignalType>>(
  (ref) => DashboardZoneController(),
);