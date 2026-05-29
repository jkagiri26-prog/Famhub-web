import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../executor/safe_dashboard_patch_executor.dart';
import '../executor/dashboard_patch_executor.dart';
import '../providers/dashboard_patch_executor_provider.dart';

/// ============================================================
/// SAFE PATCH EXECUTOR PROVIDER (HARDENED BOUNDARY LAYER)
/// ============================================================
///
/// ROLE:
/// - Pure dependency wiring ONLY
/// - Stateless factory
/// - No lifecycle ownership
/// - No runtime logic
///
/// GUARANTEE:
/// - Single composition per provider container
/// - Deterministic unsafe executor binding
/// - No runtime re-creation inside execution loops
/// ============================================================

final safeDashboardPatchExecutorProvider =
    Provider<SafeDashboardPatchExecutor>((ref) {
  /// ------------------------------------------------------------
  /// 1. DEPENDENCY RESOLUTION (IMMUTABLE GRAPH NODE)
  /// ------------------------------------------------------------
  final DashboardPatchExecutor unsafeExecutor =
      ref.read(dashboardPatchExecutorProvider);

  /// ------------------------------------------------------------
  /// 2. SAFE WRAPPER CONSTRUCTION (NO SIDE EFFECTS)
  /// ------------------------------------------------------------
  final SafeDashboardPatchExecutor safeExecutor =
      SafeDashboardPatchExecutor(
    unsafeExecutor: unsafeExecutor,
    ref: ref,
    maxRetries: 1,
  );

  /// ------------------------------------------------------------
  /// 3. DISPOSAL SAFETY (PASSIVE ONLY)
  /// ------------------------------------------------------------
  ref.onDispose(() {
    /// Intentionally no-op.
    ///
    /// SafeDashboardPatchExecutor is stateless and does not own
    /// timers, streams, or resources at this layer.
    ///
    /// This hook exists only for future-proofing.
  });

  return safeExecutor;
});