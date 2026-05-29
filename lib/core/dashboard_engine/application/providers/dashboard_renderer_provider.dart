import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import '../../domain/models/composition_node.dart';
import '../../application/resolution/widget_resolution_engine.dart';
import '../../presentation/renderer/dashboard_renderer.dart';

final widgetResolutionEngineProvider =
    Provider<WidgetResolutionEngine>((ref) {
  return const WidgetResolutionEngine();
});

final dashboardRendererProvider =
    Provider.family<DashboardRenderer, String>(
  (ref, moduleKey) {
    final engine = ref.read(widgetResolutionEngineProvider);

    return DashboardRenderer(
      widgetBuilder: (CompositionNode node) {
        return engine.resolve(
          widgetKey: node.widgetKey,
          moduleKey: node.moduleKey,
        );
      },
    );
  },
);