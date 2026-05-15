import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/widgets/farm_kpi_cards.dart';
import '../../presentation/widgets/activity_timeline_widget.dart';
import '../../presentation/widgets/farm_alerts_widget.dart';
import '../../presentation/widgets/production_summary_widget.dart';
import '../../presentation/widgets/stock_summary_widget.dart';

/// ============================================================
/// WIDGET RESOLVER SERVICE (REGISTRY LAYER v2)
/// ============================================================
///
/// Responsibilities:
/// - map widget keys → Flutter widgets
/// - inject config when needed
/// - safe fallback handling
/// ============================================================

class WidgetResolverService {
  Widget? resolve(
    String widgetKey,
    Map<String, dynamic> config,
    WidgetRef ref,
  ) {
    switch (widgetKey) {
      // =========================
      // FARM MODULE WIDGETS
      // =========================

      case 'farm_kpi_cards':
        return FarmKpiCards(config: config);

      case 'activity_timeline':
        return ActivityTimelineWidget(config: config);

      case 'farm_alerts':
        return FarmAlertsWidget(config: config);

      case 'production_summary':
        return ProductionSummaryWidget(config: config);

      case 'stock_summary':
        return StockSummaryWidget(config: config);

      // =========================
      // UNKNOWN WIDGET (DEBUG SAFE)
      // =========================

      default:
        debugPrint(
          '[WidgetResolver] Unknown widgetKey: $widgetKey',
        );
        return const SizedBox.shrink();
    }
  }
}