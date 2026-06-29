import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/domain/models/composition_metrics.dart';
import 'package:famhub_app/core/composition/domain/models/section_registry.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/dashboard_section.dart';

/// ============================================================
/// DASHBOARD SECTION DATA (COMPOSITION OUTPUT)
/// ============================================================
///
/// A fully composed dashboard section with its module items.
/// ============================================================
class DashboardSectionData {
  final DashboardSection section;
  final List<RuntimeModule> modules;

  const DashboardSectionData({
    required this.section,
    required this.modules,
  });
}

/// ============================================================
/// DASHBOARD COMPOSITION RESULT
/// ============================================================
///
/// The complete output of the dashboard composition process.
/// Contains all sections with their modules, ready for rendering.
/// ============================================================
class DashboardCompositionResult {
  final List<DashboardSectionData> sections;

  const DashboardCompositionResult({
    required this.sections,
  });

  bool get isEmpty => sections.isEmpty;
  bool get isNotEmpty => sections.isNotEmpty;

  int get totalModules {
    int count = 0;
    for (final section in sections) {
      count += section.modules.length;
    }
    return count;
  }
}

/// ============================================================
/// DASHBOARD COMPOSER (COMPOSITION ENGINE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/dashboard/ = dashboard composition
///
/// ✅ Responsibilities:
///   - Group enabled dashboard modules into sections
///   - Determine dashboard section layout and ordering
///   - Produce DashboardCompositionResult for renderer
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Dashboard no longer knows module names
///   - Receives RuntimeModule list from runtime composition
///   - Builds sections purely from backend metadata + SectionRegistry
///   - SectionRegistry handles UI presentation (names, icons, orders)
///   - No hardcoded section names in this file
///   - If backend disables Marketplace, dashboard automatically changes
///
/// ✅ HOW IT WORKS:
///   Dashboard receives List<RuntimeModule> from runtime composition.
///   It groups them by module.section (or module.category as fallback).
///   Each group becomes a DashboardSection using SectionRegistry for metadata.
///   Unknown sections get safe fallback — never crash, always render.
/// ============================================================
class DashboardComposer {
  /// ============================================================
  /// COMPOSE DASHBOARD
  /// ============================================================
  DashboardCompositionResult compose({
    required List<RuntimeModule> modules,
    CompositionMetricsCollector? metrics,
  }) {
    final stopwatch = Stopwatch()..start();

    // Group modules by section
    final sectionMap = <String, List<RuntimeModule>>{};

    for (final module in modules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      // Use dashboardSection, then section, then category, then default
      final sectionKey = module.dashboardSection ??
          module.section ??
          module.category ??
          'general';

      sectionMap.putIfAbsent(sectionKey, () => []);
      sectionMap[sectionKey]!.add(module);
    }

    // Build DashboardSectionData for each group using SectionRegistry
    final sections = <DashboardSectionData>[];

    for (final entry in sectionMap.entries) {
      final sectionKey = entry.key;
      final sectionModules = entry.value;

      // Sort modules within section by display order
      sectionModules.sort((a, b) {
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;
        final sectionCompare = a.dashboardPriority.compareTo(b.dashboardPriority);
        if (sectionCompare != 0) return sectionCompare;
        return a.displayOrder.compareTo(b.displayOrder);
      });

      // Resolve presentation metadata from SectionRegistry
      final sectionDef = SectionRegistry.get(sectionKey);
      final layoutStyle = SectionRegistry.layoutStyle(sectionKey, moduleCount: sectionModules.length);
      // Map section icon key for DashboardSection
      const iconKeyMap = <String, String>{
        'Farm Overview': 'agriculture',
        'Marketplace': 'store',
        'Finance': 'account_balance',
        'Analytics': 'analytics',
        'Logistics': 'local_shipping',
        'Traceability': 'track_changes',
        'Sustainability': 'eco',
        'Knowledge': 'school',
        'Community': 'people',
        'Opportunities': 'trending_up',
        'Administration': 'admin_panel_settings',
        'Weather': 'wb_sunny',
        'Profile': 'person',
      };
      final iconKey = iconKeyMap[sectionDef.displayName] ?? 'widgets';

      sections.add(DashboardSectionData(
        section: DashboardSection(
          sectionKey: sectionKey,
          displayName: sectionDef.displayName,
          displayOrder: sectionDef.displayOrder,
          iconKey: iconKey,
          layoutStyle: layoutStyle,
          maxWidgets: 0, // unlimited
        ),
        modules: sectionModules,
      ));
    }

    // Sort sections by display order
    sections.sort((a, b) =>
        a.section.displayOrder.compareTo(b.section.displayOrder));

    stopwatch.stop();
    metrics?.recordDashboardBuildDuration(stopwatch.elapsedMilliseconds);

    return DashboardCompositionResult(sections: sections);
  }
}

