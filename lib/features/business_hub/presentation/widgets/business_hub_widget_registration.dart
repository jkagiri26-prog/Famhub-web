/// ============================================================
/// BUSINESS HUB — WIDGET REGISTRATION BOOTSTRAP (PHASE D)
/// ============================================================
///
/// Registers Business Hub dashboard widgets with the centralized
/// WidgetRegistry so they can be driven by module descriptors and the
/// composition engine.
///
/// Architecture:
///   DashboardWidgetDescriptor → WidgetRegistry.resolve(widgetKey) →
///   BusinessHubOperationsWidget → capability profile providers
///
/// Each widget handles its own loading/empty/error states.
/// ============================================================
library;

import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/features/business_hub/presentation/widgets/business_hub_operations_widget.dart';

/// ============================================================
/// BOOTSTRAP ALL BUSINESS HUB WIDGETS
/// ============================================================
void bootstrapBusinessHubWidgets() {
  WidgetRegistry.register(
    widgetKey: 'business_hub_operations',
    builder: () => const BusinessHubOperationsWidget(),
    metadata: const WidgetRegistration(
      widgetKey: 'business_hub_operations',
      displayName: 'Business Operations',
      defaultSection: 'business_hub',
      defaultWidth: 2,
      defaultHeight: 1,
      requiresAuth: true,
    ),
  );
}
