import '../../domain/models/dashboard_render_snapshot.dart';
import '../../domain/models/zone_diff.dart';

class ZoneDiffEngine {
  const ZoneDiffEngine();

  List<ZoneDiff> generate({
    required DashboardRenderSnapshot previous,
    required DashboardRenderSnapshot next,
  }) {
    final diffs = <ZoneDiff>[];

    final allZones = {
      ...previous.zones.keys,
      ...next.zones.keys,
    };

    for (final zoneId in allZones) {
      final prevZone = previous.zones[zoneId];
      final nextZone = next.zones[zoneId];

      final prevWidgets = prevZone?.widgets ?? [];
      final nextWidgets = nextZone?.widgets ?? [];

      final diff = ZoneDiff(
        zoneId: zoneId,
        previousWidgets: prevWidgets,
        nextWidgets: nextWidgets,
      );

      if (diff.hasChanges) {
        diffs.add(diff);
      }
    }

    return diffs;
  }
}