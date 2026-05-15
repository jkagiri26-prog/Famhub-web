import '../domain/models/farm_widget_descriptor.dart';

class FarmDashboardDescriptors {
  static List<FarmWidgetDescriptor> core = [
    const FarmWidgetDescriptor(
      id: 'selector',
      type: FarmWidgetType.custom,
      order: 1,
    ),
    const FarmWidgetDescriptor(
      id: 'kpi',
      type: FarmWidgetType.custom,
      order: 2,
    ),
    const FarmWidgetDescriptor(
      id: 'activity',
      type: FarmWidgetType.activity,
      order: 3,
    ),
    const FarmWidgetDescriptor(
      id: 'production',
      type: FarmWidgetType.production,
      order: 4,
    ),
    const FarmWidgetDescriptor(
      id: 'stock',
      type: FarmWidgetType.list,
      order: 5,
    ),
    const FarmWidgetDescriptor(
      id: 'alerts',
      type: FarmWidgetType.list,
      order: 6,
    ),
    const FarmWidgetDescriptor(
      id: 'quick_actions',
      type: FarmWidgetType.custom,
      order: 7,
    ),
  ];

  static List<FarmWidgetDescriptor> premium = [
    const FarmWidgetDescriptor(
      id: 'advanced_analytics',
      type: FarmWidgetType.custom,
      order: 10,
    ),
    const FarmWidgetDescriptor(
      id: 'carbon_dashboard',
      type: FarmWidgetType.custom,
      order: 11,
    ),
    const FarmWidgetDescriptor(
      id: 'ai_advisory',
      type: FarmWidgetType.custom,
      order: 12,
    ),
  ];
}