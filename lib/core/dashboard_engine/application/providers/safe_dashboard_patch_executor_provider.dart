import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/executor/safe_dashboard_patch_executor.dart';
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
  final SafeDashboardPatchExecutor safeExecutor =
      SafeDashboardPatchExecutor(
    ref: ref,
  );

  /// ------------------------------------------------------------
  /// DISPOSAL SAFETY (PASSIVE ONLY)
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