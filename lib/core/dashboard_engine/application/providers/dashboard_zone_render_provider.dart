import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardZoneRenderProvider =
    StateNotifierProvider<DashboardZoneRenderNotifier, Map<String, bool>>(
  (ref) => DashboardZoneRenderNotifier(),
);

class DashboardZoneRenderNotifier
    extends StateNotifier<Map<String, bool>> {
  DashboardZoneRenderNotifier() : super(const {});

  /// ============================================================
  /// MARK ZONE DIRTY
  /// ============================================================
  void markZoneDirty(String zoneId) {
    state = {
      ...state,
      zoneId: true,
    };
  }

  /// ============================================================
  /// CLEAR SINGLE ZONE
  /// ============================================================
  void clearZone(String zoneId) {
    if (!state.containsKey(zoneId)) return;

    final updated = Map<String, bool>.from(state);
    updated[zoneId] = false;

    state = updated;
  }

  /// ============================================================
  /// CLEAR ALL ZONES (useful after full render pass)
  /// ============================================================
  void clearAll() {
    if (state.isEmpty) return;
    state = const {};
  }

  /// ============================================================
  /// RESET ONLY DIRTY FLAGS (keeps keys stable)
  /// ============================================================
  void resetDirtyFlags() {
    if (state.isEmpty) return;

    state = {
      for (final entry in state.entries) entry.key: false,
    };
  }
}