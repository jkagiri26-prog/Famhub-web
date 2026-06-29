/// ============================================================
/// WIDGET REGISTRATION BOOTSTRAP
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/presentation/builders/ = builders
///
/// ✅ Responsibilities:
///   - Central bootstrap for widget registration
///   - Each feature module registers its widgets here
///   - Bridge legacy WidgetBuilderRegistry registrations
///   - Called once at app startup
///
/// ✅ This file is the ONLY place where widget registrations
///    are defined. The renderer never uses switch statements
///    or conditional logic to select widgets.
///
/// ❌ Does NOT:
///   - Import feature pages/views
///   - Contain business logic
///   - Render widgets
/// ============================================================
library;

import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_builder_registry.dart';

/// ============================================================
/// BOOTSTRAP ALL WIDGET REGISTRATIONS
/// ============================================================
///
/// Call this once during app initialization.
/// Bridges all legacy registrations to the new WidgetRegistry.
/// ============================================================
void bootstrapWidgetRegistrations() {
  // ── Bridge all legacy WidgetBuilderRegistry entries ──
  // This ensures backward compatibility during migration.
  WidgetRegistry.bridgeAllLegacy();

  // ── Future: Feature modules register widgets here ──
  // Each feature module should add its own bootstrap function:
  //
  // bootstrapFarmManagementWidgets();
  // bootstrapMarketplaceWidgets();
  // bootstrapFinanceWidgets();
  // bootstrapKnowledgeWidgets();
  //
  // Example:
  // WidgetRegistry.register(
  //   widgetKey: 'farm_overview',
  //   builder: () => const FarmOverviewWidget(),
  //   metadata: WidgetRegistration(
  //     widgetKey: 'farm_overview',
  //     displayName: 'Farm Overview',
  //     defaultSection: 'farm',
  //     defaultWidth: 2,
  //     defaultHeight: 1,
  //   ),
  // );
}
