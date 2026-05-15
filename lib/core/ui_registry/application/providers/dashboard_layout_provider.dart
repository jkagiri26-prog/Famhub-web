import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/dashboard_widget_layout.dart';
import '../infrastructure/repositories/dashboard_layout_repository.dart';

final dashboardLayoutRepositoryProvider =
    Provider((ref) => DashboardLayoutRepository());

final dashboardLayoutProvider =
    FutureProvider.family<List<DashboardWidgetLayout>, String>(
        (ref, moduleKey) async {
  final repo = ref.watch(dashboardLayoutRepositoryProvider);
  return repo.fetchLayout(moduleKey);
});