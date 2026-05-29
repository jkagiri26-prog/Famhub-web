import '../../domain/models/module_zone_mapping.dart';
import 'package:famhub_app/core/dashboard_engine/infrastructure/repositories/module_zone_mapping_repository.dart';

class ModuleZoneMappingEngine {
  ModuleZoneMappingEngine({
    required this.repository,
    required this.fallback,
  });

  final ModuleZoneMappingRepository repository;

  /// fallback = your existing static registry
  final Map<String, String> fallback;

  Map<String, String>? _cache;

  /// ============================================================
  /// LOAD FROM BACKEND
  /// ============================================================
  Future<void> warmUp() async {
    final mappings = await repository.fetchMappings();

    _cache = {
      for (final m in mappings) m.moduleKey: m.zoneId,
    };
  }

  /// ============================================================
  /// RESOLVE ZONE
  /// ============================================================
  String resolveZone(String moduleKey) {
    return _cache?[moduleKey] ??
        fallback[moduleKey] ??
        'main';
  }
}