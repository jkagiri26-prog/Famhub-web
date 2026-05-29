import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/dashboard_state_store.dart';
import '../composition/dashboard_composition_engine.dart';
import '../infrastructure/services/dashboard_renderer_service.dart';

class UnifiedDashboardHost extends ConsumerStatefulWidget {
  final String moduleKey;

  const UnifiedDashboardHost({
    super.key,
    required this.moduleKey,
  });

  @override
  ConsumerState<UnifiedDashboardHost> createState() =>
      _UnifiedDashboardHostState();
}

class _UnifiedDashboardHostState
    extends ConsumerState<UnifiedDashboardHost> {
  @override
  Widget build(BuildContext context) {
    /// ============================================================
    /// SINGLE SOURCE OF TRUTH (READ ONLY STATE)
    /// ============================================================
    final state = ref.watch(
      dashboardStateStoreProvider(widget.moduleKey),
    );

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    /// ============================================================
    /// PURE COMPOSITION LAYER (NO SIDE EFFECTS ALLOWED)
    /// ============================================================
    final compositionEngine =
        ref.read(dashboardCompositionEngineProvider);

    final renderer =
        ref.read(dashboardRendererProvider(widget.moduleKey));

    final composed = compositionEngine.buildSync(
      context: _buildContext(context),
      modules: state.modules,
    );

    /// ============================================================
    /// PURE RENDER OUTPUT (NO EVENT SUBSCRIPTIONS, NO MUTATIONS)
    /// ============================================================
    return renderer.render(
      snapshot: composed,
      zoneState: state.zoneState,
    );
  }

  /// ============================================================
  /// DEVICE CONTEXT DERIVATION (PURE FUNCTION)
  /// ============================================================
  LayoutContext _buildContext(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return LayoutContext(
      device: width >= 1100
          ? LayoutDeviceType.desktop
          : width >= 600
              ? LayoutDeviceType.tablet
              : LayoutDeviceType.mobile,
    );
  }
}