import 'package:flutter/widgets.dart';

import '../../application/composition/composition_snapshot.dart';
import '../../domain/models/composition_node.dart';
import 'dashboard_renderer_widget.dart';

/// ============================================================
/// DASHBOARD RENDERER (PRESENTATION FACADE)
/// ============================================================
///
/// Stable API layer for rendering CompositionSnapshot.
///
/// ❌ MUST NOT:
/// - contain layout logic
/// - resolve modules
/// - manage state
/// ============================================================
class DashboardRenderer {
  /// Stable node → widget mapping function
  final Widget Function(CompositionNode node) widgetBuilder;

  const DashboardRenderer({
    required this.widgetBuilder,
  });

  /// ============================================================
  /// RENDER SNAPSHOT → UI
  /// ============================================================
  Widget render({
    required CompositionSnapshot snapshot,
  }) {
    return DashboardRendererWidget(
      snapshot: snapshot,
      builder: widgetBuilder,
    );
  }
}