/// ============================================================
/// LOGISTICS PERMISSION PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Resolve Logistics permission keys through the existing
///     canonical backend authorization function
///     `core.has_permission(p_permission)` reached via
///     `AccessPolicyRepository.hasPermission`.
///   - Expose a safe loading / unavailable / allowed / denied state.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - No permission is granted here. When the backend does not
///     explicitly allow a key, it is NOT rendered.
///   - When permission data is unavailable the state is `unavailable`
///     so the UI can show a locked state instead of fabricating access.
///   - Mirrors the established `adminCapabilityStatusProvider` pattern.
///
/// ❌ Does NOT:
///   - Grant or persist permissions
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/access/application/providers/access_policy_provider.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';

/// Resolution state of a single backend permission key.
enum LogisticsPermissionState {
  /// Context/permission data is still resolving.
  loading,

  /// Permission data is not available — render a locked state.
  unavailable,

  /// The backend explicitly allowed the permission.
  allowed,

  /// The backend explicitly denied the permission.
  denied,
}

class LogisticsPermissionStatus {
  final LogisticsPermissionState state;
  final String? reason;

  const LogisticsPermissionStatus(this.state, [this.reason]);

  bool get isAllowed => state == LogisticsPermissionState.allowed;
  bool get isLoading => state == LogisticsPermissionState.loading;
  bool get isUnavailable => state == LogisticsPermissionState.unavailable;

  static const LogisticsPermissionStatus loading =
      LogisticsPermissionStatus(LogisticsPermissionState.loading);

  static const LogisticsPermissionStatus allowed =
      LogisticsPermissionStatus(LogisticsPermissionState.allowed);
}

/// ============================================================
/// PROVIDER: SINGLE LOGISTICS PERMISSION STATUS
/// ============================================================
///
/// Resolves one backend permission key. The active entity context is
/// derived by the existing FAMHUB context mechanism — nothing is
/// supplied by the caller.
/// ============================================================
final logisticsPermissionProvider =
    FutureProvider.family<LogisticsPermissionStatus, String>((
  ref,
  permissionKey,
) async {
  final context = ref.watch(contextProvider);

  if (context.isLoading) return LogisticsPermissionStatus.loading;

  if (context.isGuest) {
    return const LogisticsPermissionStatus(
      LogisticsPermissionState.unavailable,
      'Sign in to check your Logistics permissions.',
    );
  }

  final repository = ref.watch(accessPolicyRepositoryProvider);
  try {
    final allowed = await repository.hasPermission(permissionKey);
    if (allowed) return LogisticsPermissionStatus.allowed;

    return LogisticsPermissionStatus(
      LogisticsPermissionState.denied,
      'Permission "$permissionKey" is not granted for the active context.',
    );
  } catch (_) {
    return const LogisticsPermissionStatus(
      LogisticsPermissionState.unavailable,
      'Permissions are not available right now.',
    );
  }
});

/// ============================================================
/// PROVIDER: SYNCHRONOUS PERMISSION STATUS (UI-friendly)
/// ============================================================
///
/// Flattens the async resolution into a status the UI can branch on
/// without ever throwing or fabricating access.
/// ============================================================
final logisticsPermissionStatusProvider =
    Provider.family<LogisticsPermissionStatus, String>((ref, permissionKey) {
  final async = ref.watch(logisticsPermissionProvider(permissionKey));
  return async.when(
    data: (status) => status,
    loading: () => LogisticsPermissionStatus.loading,
    error: (_, __) => const LogisticsPermissionStatus(
      LogisticsPermissionState.unavailable,
      'Permissions are not available right now.',
    ),
  );
});
