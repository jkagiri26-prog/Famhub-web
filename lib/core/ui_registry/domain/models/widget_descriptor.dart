import '../../../../core/ui_registry/domain/models/widget_descriptor.dart';

class FarmDashboardComposer {
  List<WidgetDescriptor> build() {
    return const [
      WidgetDescriptor(
        id: 'farm_selector',
        featureKey: 'farm_selector',
        order: 0,
        flex: 1,
      ),
      WidgetDescriptor(
        id: 'farm_kpis',
        featureKey: 'farm_kpis',
        order: 1,
        flex: 1,
      ),
      WidgetDescriptor(
        id: 'farm_activity',
        featureKey: 'farm_activity',
        order: 2,
        flex: 1,
      ),
      WidgetDescriptor(
        id: 'farm_production',
        featureKey: 'farm_production',
        order: 3,
        flex: 1,
      ),
      WidgetDescriptor(
        id: 'farm_stock',
        featureKey: 'farm_stock',
        order: 4,
        flex: 1,
      ),
      WidgetDescriptor(
        id: 'farm_alerts',
        featureKey: 'farm_alerts',
        order: 5,
        flex: 1,
      ),
      WidgetDescriptor(
        id: 'farm_quick_actions',
        featureKey: 'farm_quick_actions',
        order: 6,
        flex: 1,
      ),
    ];
  }
}