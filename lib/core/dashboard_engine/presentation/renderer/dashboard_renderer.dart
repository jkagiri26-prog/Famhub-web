import 'package:flutter/widgets.dart';

import 'package:famhub_app/core/dashboard_engine/application/composition/composition_snapshot.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/composition_node.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/renderer/dashboard_renderer_widget.dart';

/// ============================================================
/// DASHBOARD RENDERER (PRESENTATION FACADE)
/// ============================================================
///
/// This is the ONLY public rendering entry point.
///
/// It assumes:
/// ✔ CompositionSnapshot is fully resolved
/// ✔ Access rules already applied
/// ✔ Zone placement already determined
/// ✔ Ordering already deterministic
///
/// It does NOT:
/// ❌ resolve modules
/// ❌ compute layout
/// ❌ apply access rules
/// ❌ apply zone logic
/// ============================================================
class DashboardRenderer {
  /// Pure node → widget mapping function
  final Widget Function(CompositionNode node) widgetBuilder;

  const DashboardRenderer({
    required this.widgetBuilder,
  });

  /// ============================================================
  /// SNAPSHOT → UI RENDER
  /// ============================================================
  Widget render({
    required CompositionSnapshot snapshot,
  }) {
    if (snapshot.isEmpty) {
      return const SizedBox.shrink();
    }

    return DashboardRendererWidget(
      snapshot: snapshot,
      builder: widgetBuilder,
    );
  }
}