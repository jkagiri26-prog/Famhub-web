import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../executor/dashboard_patch_executor.dart';

/// ============================================================
/// DASHBOARD PATCH EXECUTOR PROVIDER
/// ============================================================
///
/// ROLE:
/// - Single source of truth for unsafe patch execution kernel
/// - Stateless DI factory
/// - No side effects
/// - No scheduling logic
/// ============================================================

final dashboardPatchExecutorProvider =
    Provider<DashboardPatchExecutor>((ref) {
  return DashboardPatchExecutor(ref: ref);
});