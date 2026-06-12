import 'package:flutter/widgets.dart';

import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_builder_registry.dart';

/// ============================================================
/// DASHBOARD BOOTSTRAP CONFIG
/// ============================================================
///
/// Defines everything needed to initialize dashboard engine
/// in a deterministic way.
/// ============================================================

class DashboardBootstrapConfig {
  final Map<String, DashboardWidgetBuilder> widgetBuilders;

  const DashboardBootstrapConfig({
    required this.widgetBuilders,
  });
}