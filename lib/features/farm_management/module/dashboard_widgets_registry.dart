import '../../../system/registry/dashboard_registry.dart';
import '../presentation/widgets/activity_timeline_widget.dart';
import '../presentation/widgets/farm_alerts_widget.dart';
import '../presentation/widgets/farm_kpi_cards.dart';
import '../presentation/widgets/farm_selector_widget.dart';
import '../presentation/widgets/production_summary_widget.dart';
import '../presentation/widgets/quick_actions.dart';
import '../presentation/widgets/stock_summary_widget.dart';

class FarmDashboardWidgetsRegistry {
  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;

    DashboardRegistry.register(
      'farm_kpis',
      () => const FarmKpiCards(),
    );
    DashboardRegistry.register(
      'farm_activity_timeline',
      () => const ActivityTimelineWidget(),
    );
    DashboardRegistry.register(
      'farm_production_summary',
      () => const ProductionSummaryWidget(),
    );
    DashboardRegistry.register(
      'farm_stock_summary',
      () => const StockSummaryWidget(),
    );
    DashboardRegistry.register(
      'farm_alerts',
      () => const FarmAlertsWidget(),
    );
    DashboardRegistry.register(
      'farm_quick_actions',
      () => const FarmQuickActions(),
    );
    DashboardRegistry.register(
      'farm_farm_selector',
      () => const FarmSelectorWidget(),
    );
  }
}

