import 'dashboard_zone_model.dart';

class DashboardRenderSnapshot {
  const DashboardRenderSnapshot({
    required this.zones,
  });

  final Map<String, DashboardZoneModel> zones;
}