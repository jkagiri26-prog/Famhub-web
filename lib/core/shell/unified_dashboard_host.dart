import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/dashboard_provider.dart';
import '../../infrastructure/services/dashboard_renderer_service.dart';
import '../../infrastructure/resolvers/widget_resolver_service.dart';

import '../../infrastructure/composition/dashboard_composition_engine.dart';
import '../../application/services/dashboard_layout_preset_engine.dart';
import '../../domain/models/dashboard_layout_presets.dart';

class UnifiedDashboardHost extends ConsumerWidget {
  final String moduleKey;

  const UnifiedDashboardHost({
    super.key,
    required this.moduleKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDescriptors = ref.watch(
      dashboardProvider(moduleKey),
    );

    return asyncDescriptors.when(
      data: (descriptors) {
        final renderer = DashboardRendererService(
          widgetResolver: WidgetResolverService(),
        );

        /// 1. BUILD ZONES
        final zonesMap = renderer.renderByZones(
          descriptors,
          ref,
          context,
        );

        final zones = DashboardZoneData(
          header: zonesMap['header'] ?? [],
          main: zonesMap['main'] ?? [],
          sidebar: zonesMap['sidebar'] ?? [],
          footer: zonesMap['footer'] ?? [],
        );

        /// 2. LAYOUT PRESET ENGINE (DOMAIN-CORRECT)
        final presetEngine = DashboardLayoutPresetEngine(
          presets: DashboardLayoutPresets.defaults(),
        );

        final deviceType = _deviceType(context);

        final preset = presetEngine.resolve(
          selectedKey: null,
          deviceType: deviceType,
        );

        /// 3. COMPOSITION ENGINE (UI STRUCTURE)
        final composer = DashboardCompositionEngine();

        return composer.compose(
          zones: zones,
          context: context,
          layoutType: preset.layoutType,
        );
      },

      loading: () =>
          const Center(child: CircularProgressIndicator()),

      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  String _deviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1100) return 'desktop';
    if (width >= 600) return 'tablet';
    return 'mobile';
  }
}