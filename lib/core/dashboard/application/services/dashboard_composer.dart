import 'package:flutter/material.dart';

import '../../../../features/dashboard/domain/models/dashboard_descriptor.dart';
import '../../infrastructure/services/dashboard_renderer_service.dart';
import '../../infrastructure/resolvers/widget_resolver_service.dart';
import '../../infrastructure/services/dashboard_layout_compiler.dart';

/// ============================================================
/// DASHBOARD BUILDER (LEGACY COMPAT ADAPTER)
/// ============================================================
///
/// This class is no longer part of the primary pipeline.
///
/// Primary pipeline:
/// RendererService → LayoutCompiler → WidgetResolver
///
/// This is kept for:
/// - legacy modules
/// - migration safety
/// - quick static builds
/// ============================================================

class DashboardBuilder {
  static Widget build(
    List<DashboardDescriptor> descriptors,
    BuildContext context,
  ) {
    final renderer = DashboardRendererService(
      widgetResolver: WidgetResolverService(),
      layoutCompiler: DashboardLayoutCompiler(),
    );

    final zones = renderer.renderByZones(
      descriptors,
      null, // legacy fallback (no Riverpod context)
      context,
    );

    return Column(
      children: [
        ...zones['header'] ?? [],
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: zones['main'] ?? [],
            ),
          ),
        ),
        ...zones['footer'] ?? [],
      ],
    );
  }
}