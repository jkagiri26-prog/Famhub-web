import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/controllers/farm_dashboard_controller.dart';
import 'package:famhub_app/features/farm_management/application/state/farm_dashboard_state.dart';

final farmDashboardProvider = AsyncNotifierProvider<
    FarmDashboardController, FarmDashboardState>(
  FarmDashboardController.new,
);