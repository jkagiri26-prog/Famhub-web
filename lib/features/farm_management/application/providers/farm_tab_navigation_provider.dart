/// ============================================================
/// FARM TAB NAVIGATION PROVIDER — In-module tab switch requests
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/ = application providers
///
/// ✅ Why this exists:
///   Dashboard widgets (e.g. the farm selector) are resolved through the
///   WidgetRegistry with zero constructor arguments, so they have no
///   callback wiring to FarmManagementPage's TabController. They request
///   tab switches here instead — e.g. "Open" on a farm must open that
///   farm's details INSIDE the My Farms tab rather than pushing a
///   standalone route over the tab shell.
///
/// ✅ FarmManagementPage listens to [farmTabNavigationProvider] in
///   build() and animates its TabController accordingly.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab indexes of the Farm Management workspace tabs.
///
/// Must stay in sync with `FarmManagementPage._tabDefs` order.
class FarmManagementTab {
  FarmManagementTab._();

  static const int overview = 0;
  static const int myFarms = 1;
  static const int crops = 2;
  static const int livestock = 3;
  static const int activityLogs = 4;
  static const int reports = 5;
}

/// A single tab-switch request.
///
/// [sequence] increases on every request so repeating the same target
/// tab (e.g. Open → My Farms twice in a row) still notifies listeners.
class FarmTabRequest {
  const FarmTabRequest({required this.tabIndex, required this.sequence});

  final int tabIndex;
  final int sequence;
}

class FarmTabNavigationNotifier extends Notifier<FarmTabRequest?> {
  @override
  FarmTabRequest? build() => null;

  /// Ask the parent Farm Management page to switch to [tabIndex].
  void goTo(int tabIndex) {
    state = FarmTabRequest(
      tabIndex: tabIndex,
      sequence: (state?.sequence ?? 0) + 1,
    );
  }
}

final farmTabNavigationProvider =
    NotifierProvider<FarmTabNavigationNotifier, FarmTabRequest?>(
  FarmTabNavigationNotifier.new,
);
