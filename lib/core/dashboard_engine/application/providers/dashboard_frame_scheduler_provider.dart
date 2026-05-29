import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../scheduler/dashboard_frame_scheduler.dart';

final dashboardFrameSchedulerProvider =
    Provider<DashboardFrameScheduler>((ref) {
  final scheduler = DashboardFrameScheduler();

  ref.onDispose(() {
    // Future-proofing only (no timers inside scheduler yet)
  });

  return scheduler;
});