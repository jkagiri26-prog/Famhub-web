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