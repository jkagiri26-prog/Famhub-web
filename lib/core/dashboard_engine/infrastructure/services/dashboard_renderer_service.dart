import 'package:flutter/material.dart';

import '../../domain/models/dashboard_render_snapshot.dart';

class DashboardRendererService {
  const DashboardRendererService();

  Widget render({
    required DashboardRenderSnapshot snapshot,
    required Map<String, bool> zoneState,
  }) {
    return Column(
      children: snapshot.zones.entries.map((entry) {
        final zoneId = entry.key;
        final zone = entry.value;

        final isDirty = zoneState[zoneId] ?? false;

        return _ZoneRenderer(
          zoneId: zoneId,
          zone: zone,
          isDirty: isDirty,
        );
      }).toList(),
    );
  }
}