import 'package:flutter/material.dart';

import '../../features/farm_management/presentation/widgets/farm_kpi_cards.dart';
import '../../features/farm_management/presentation/widgets/farm_selector_widget.dart';
import '../../features/farm_management/presentation/widgets/activity_timeline_widget.dart';
import '../../features/farm_management/presentation/widgets/production_summary_widget.dart';
import '../../features/farm_management/presentation/widgets/stock_summary_widget.dart';
import '../../features/farm_management/presentation/widgets/farm_alerts_widget.dart';
import '../../features/farm_management/presentation/widgets/quick_actions.dart';

class WidgetRegistry {
  static Widget resolve(String id) {
    switch (id) {
      case 'farm_selector':
        return const FarmSelectorWidget();
      case 'farm_kpis':
        return const FarmKpiCards();
      case 'farm_activity':
        return const ActivityTimelineWidget();
      case 'farm_production':
        return const ProductionSummaryWidget();
      case 'farm_stock':
        return const StockSummaryWidget();
      case 'farm_alerts':
        return const FarmAlertsWidget();
      case 'farm_quick_actions':
        return const FarmQuickActions();

      default:
        return const SizedBox.shrink();
    }
  }
}