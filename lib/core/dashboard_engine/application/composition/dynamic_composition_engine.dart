import 'package:famhub_app/core/dashboard_engine/domain/models/dashboard_section.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/dashboard_widget_definition.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/layout_context.dart';
import 'package:famhub_app/core/feature_flags/application/services/runtime_feature_flags.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';

/// ============================================================
/// DYNAMIC COMPOSITION ENGINE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/composition/ = composition
///
/// ✅ Responsibilities:
///   - Compose dashboard sections dynamically from backend metadata
///   - Place widgets into sections based on backend definitions
///   - Evaluate all governance rules before inclusion
///   - Calculate responsive layout placement
///   - No hardcoded sections or widget references
///
/// ✅ Backend defines:
///   - Which sections exist
///   - Which widgets belong to each section
///   - Widget dimensions (width, height)
///   - Widget priority and order
///   - Visibility rules per device
///
/// ❌ Does NOT:
///   - Render widgets
///   - Import Flutter UI
///   - Hardcode composition logic
/// ============================================================

/// ============================================================
/// COMPOSED SECTION (RESULT DATA)
/// ============================================================
///
/// A fully composed section with its widgets,
/// ready for the renderer.
/// ============================================================
class ComposedSection {
  final DashboardSection section;
  final List<DashboardWidgetDefinition> widgets;

  const ComposedSection({
    required this.section,
    required this.widgets,
  });

  bool get isEmpty => widgets.isEmpty;
  bool get isNotEmpty => widgets.isNotEmpty;
}

/// ============================================================
/// DYNAMIC COMPOSITION ENGINE
/// ============================================================
class DynamicCompositionEngine {
  /// ============================================================
  /// COMPOSE SECTIONS
  /// ============================================================
  ///
  /// Takes backend-defined sections and widget definitions,
  /// evaluates governance rules, and produces ComposedSections
  /// ready for the renderer.
  ///
  /// [sections] - Backend-defined dashboard sections
  /// [widgetDefinitions] - Backend-defined widget placements
  /// [context] - Current user context
  /// [layoutContext] - Current device layout context
  /// ============================================================
  static List<ComposedSection> compose({
    required List<DashboardSection> sections,
    required List<DashboardWidgetDefinition> widgetDefinitions,
    required EntityContext context,
    required LayoutContext layoutContext,
  }) {
    final deviceType = _deviceTypeToString(layoutContext.device);
    final composedSections = <ComposedSection>[];

    for (final section in sections) {
      // ── Evaluate section governance ──
      final sectionResult = RuntimeFeatureFlags.evaluateSection(
        sectionKey: section.sectionKey,
        context: context,
        requiredRole: section.requiredRole,
        requiredEntityType: section.requiredEntityType,
      );
      if (!sectionResult.isAllowed) continue;

      // ── Filter widgets for this section ──
      final sectionWidgets = widgetDefinitions
          .where((w) => w.sectionKey == section.sectionKey)
          .where((w) {
            // Evaluate each widget through governance
            final widgetResult = RuntimeFeatureFlags.evaluateWidget(
              widget: w,
              context: context,
              deviceType: deviceType,
            );
            return widgetResult.isAllowed;
          })
          .toList()
        ..sort((a, b) {
          // Sort by priority (higher first), then display order
          final priority = b.priority.compareTo(a.priority);
          return priority != 0 ? priority : a.displayOrder.compareTo(b.displayOrder);
        });

      // ── Apply max widgets limit ──
      final limitedWidgets = section.maxWidgets > 0
          ? sectionWidgets.take(section.maxWidgets).toList()
          : sectionWidgets;

      // ── Calculate responsive layout ──
      final placedWidgets = _calculateResponsivePlacement(
        limitedWidgets,
        layoutContext,
      );

      if (placedWidgets.isNotEmpty) {
        composedSections.add(ComposedSection(
          section: section,
          widgets: placedWidgets,
        ));
      }
    }

    return composedSections;
  }

  /// ============================================================
  /// RESPONSIVE PLACEMENT CALCULATOR
  /// ============================================================
  ///
  /// Calculates widget placement for responsive grid.
  /// Desktop: multi-column grid
  /// Tablet: 2-column grid
  /// Mobile: single column
  /// ============================================================
  static List<DashboardWidgetDefinition> _calculateResponsivePlacement(
    List<DashboardWidgetDefinition> widgets,
    LayoutContext context,
  ) {
    // Filter by device compatibility
    return widgets.where((w) {
      if (context.isMobile && !w.showOnMobile) return false;
      if (context.isTablet && !w.showOnTablet) return false;
      if (context.isDesktop && !w.showOnDesktop) return false;
      return true;
    }).toList();
  }

  /// ============================================================
  /// DEVICE TYPE STRING HELPER
  /// ============================================================
  static String _deviceTypeToString(LayoutDeviceType device) {
    switch (device) {
      case LayoutDeviceType.mobile:
        return 'mobile';
      case LayoutDeviceType.tablet:
        return 'tablet';
      case LayoutDeviceType.desktop:
        return 'desktop';
    }
  }
}
