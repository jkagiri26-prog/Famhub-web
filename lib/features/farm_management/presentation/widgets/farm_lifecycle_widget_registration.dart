/// ============================================================
/// FARM LIFECYCLE — WIDGET REGISTRATION BOOTSTRAP
/// ============================================================
///
/// Registers lifecycle-aware dashboard widgets with the WidgetRegistry.
/// Call this during farm module initialization alongside
/// farm_widget_registration_bootstrap.dart.
///
/// This is Phase 7 of the Farm Management module evolution:
///   Lifecycle-driven dashboard.
/// ============================================================
library;

import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_lifecycle_stage_widget.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_recommendations_widget.dart';

/// Register all lifecycle-aware dashboard widgets.
void bootstrapLifecycleWidgets() {
  WidgetRegistry.register(
    widgetKey: 'farm_lifecycle_stage',
    builder: () => const FarmLifecycleStageWidget(),
    metadata: const WidgetRegistration(
      widgetKey: 'farm_lifecycle_stage',
      displayName: 'Lifecycle Stage',
      defaultSection: 'primary',
      defaultWidth: 2,
      defaultHeight: 2,
      defaultRefreshInterval: 30,
    ),
  );

  WidgetRegistry.register(
    widgetKey: 'farm_recommendations',
    builder: () => const FarmRecommendationsWidget(),
    metadata: const WidgetRegistration(
      widgetKey: 'farm_recommendations',
      displayName: 'Recommendations',
      defaultSection: 'primary',
      defaultWidth: 2,
      defaultHeight: 2,
      defaultRefreshInterval: 60,
    ),
  );
}