import '../../domain/models/dashboard_zone_model.dart';
import '../../domain/models/dashboard_render_snapshot.dart';
import '../../domain/models/dashboard_module_definition.dart';
import '../mapping/module_zone_mapping_engine.dart';

class DashboardZoneComposer {
  DashboardZoneComposer({
    required this.mappingEngine,
  });

  final ModuleZoneMappingEngine mappingEngine;

  DashboardRenderSnapshot composeZones(
    List<DashboardModuleDefinition> modules,
  ) {
    final Map<String, List<DashboardModuleDefinition>> zoneBuckets = {};

    /// ============================================================
    /// GROUP MODULES BY RESOLVED ZONE (PRIMARY AUTHORITY)
    /// ============================================================
    for (final module in modules) {
      final zoneId = mappingEngine.resolveZone(
        module.moduleKey,
      );

      zoneBuckets.putIfAbsent(zoneId, () => []);
      zoneBuckets[zoneId]!.add(module);
    }

    /// ============================================================
    /// BUILD ZONE MODEL SNAPSHOT
    /// ============================================================
    final zones = zoneBuckets.map((zoneId, mods) {
      return MapEntry(
        zoneId,
        DashboardZoneModel(
          id: zoneId,

          /// PURE PRESENTATION TRANSFORMATION ONLY
          widgets: mods.map((m) => m.widget).toList(),
        ),
      );
    });

    return DashboardRenderSnapshot(
      zones: zones,
    );
  }
}