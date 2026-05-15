import '../models/dashboard_layout_preset.dart';
import '../models/dashboard_layout_type.dart';

class DashboardLayoutPresets {
  static List<DashboardLayoutPreset> defaults() {
    return const [
      DashboardLayoutPreset(
        key: 'default_grid',
        name: 'Default Grid',
        layoutType: DashboardLayoutType.grid,
        isDefault: true,
      ),

      DashboardLayoutPreset(
        key: 'desktop_split',
        name: 'Desktop Split View',
        layoutType: DashboardLayoutType.split,
      ),

      DashboardLayoutPreset(
        key: 'mobile_stack',
        name: 'Mobile Stack',
        layoutType: DashboardLayoutType.stacked,
      ),

      DashboardLayoutPreset(
        key: 'tablet_mix',
        name: 'Tablet Mixed Layout',
        layoutType: DashboardLayoutType.mixed,
      ),
    ];
  }
}