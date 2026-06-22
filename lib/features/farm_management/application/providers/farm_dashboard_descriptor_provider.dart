import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/farm_widget_descriptor.dart';

final farmDashboardDescriptorProvider =
    Provider<List<FarmWidgetDescriptor>>((ref) {
  return const [
    FarmWidgetDescriptor(
      id: 'summary',
      type: FarmWidgetType.summary,
      order: 1,
    ),
    FarmWidgetDescriptor(
      id: 'activity',
      type: FarmWidgetType.activity,
      order: 2,
    ),
    FarmWidgetDescriptor(
      id: 'production',
      type: FarmWidgetType.production,
      order: 3,
    ),
  ];
});