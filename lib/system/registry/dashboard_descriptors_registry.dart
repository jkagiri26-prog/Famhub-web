import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_descriptor.dart';

final dashboardDescriptorRegistryProvider =
    Provider<DashboardDescriptorRegistry>((ref) {
  return DashboardDescriptorRegistry();
});

class DashboardDescriptorRegistry {
  final Map<String, List<DashboardDescriptor>> _registry = {};

  void register(String moduleKey, List<DashboardDescriptor> descriptors) {
    _registry[moduleKey] = descriptors;
  }

  List<DashboardDescriptor>? get(String moduleKey) {
    return _registry[moduleKey];
  }
}