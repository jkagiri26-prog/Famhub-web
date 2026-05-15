import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/farm_dashboard_controller.dart';
import '../state/farm_dashboard_state.dart';

final farmDashboardProvider = AsyncNotifierProvider<
    FarmDashboardController, FarmDashboardState>(
  FarmDashboardController.new,
);