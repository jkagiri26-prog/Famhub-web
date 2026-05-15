import '../domain/models/farm_widget_descriptor.dart';
import 'widgets/farm_summary_widget.dart';
import 'widgets/farm_activity_widget.dart';
import 'widgets/farm_production_widget.dart';

class FarmWidgetMapper {
  static dynamic map(FarmWidgetDescriptor descriptor) {
    switch (descriptor.type) {
      case FarmWidgetType.summary:
        return FarmSummaryWidget(config: descriptor.config);

      case FarmWidgetType.activity:
        return FarmActivityWidget(config: descriptor.config);

      case FarmWidgetType.production:
        return FarmProductionWidget(config: descriptor.config);

      case FarmWidgetType.chart:
        // placeholder for future chart widget
        return FarmSummaryWidget(config: descriptor.config);

      case FarmWidgetType.list:
        return FarmActivityWidget(config: descriptor.config);

      case FarmWidgetType.custom:
        return Container(); // safe fallback
    }
  }
}