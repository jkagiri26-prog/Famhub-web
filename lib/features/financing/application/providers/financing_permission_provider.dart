/// ============================================================
/// FINANCING PERMISSION PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Resolve Financing permission keys through the canonical backend
///     authorization function `core.has_permission(p_permission)` reached via
///     `AccessPolicyRepository.hasPermission`.
///   - Expose a safe loading / unavailable / allowed / denied state.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - No permission is granted here. The Phase 1 migration registers the
///     five `finance.*` codes but seeds NO role_permissions and NO
///     entity_role_scopes rows, so the backend fails closed with 42501 for
///     every role. This code does not compensate for that: when the backend
///     denies or errors, the state is `denied` / `unavailable` and the UI
///     shows a locked state instead of fabricating access.
///   - Mirrors the established `logisticsPermissionStatusProvider` pattern.
///
/// ❌ Does NOT:
///   - Grant or persist permissions
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/access/application/providers/access_policy_provider.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/financing/config/permissions.dart';

/// Resolution state of a single backend permission key.
enum FinancingPermissionState {
  loading,
  unavailable,
  allowed,
  denied,
}

class FinancingPermissionStatus {
  final FinancingPermissionState state;
  final String? reason;

  const FinancingPermissionStatus(this.state, [this.reason]);

  bool get isAllowed => state == FinancingPermissionState.allowed;
  bool get isLoading => state == FinancingPermissionState.loading;
  bool get isUnavailable => state == FinancingPermissionState.unavailable;

  static const FinancingPermissionStatus loading =
      FinancingPermissionStatus(FinancingPermissionState.loading);

  static const FinancingPermissionStatus allowed =
      FinancingPermissionStatus(FinancingPermissionState.allowed);
}

/// Single backend permission check — `core.has_permission(p_permission)`.
typedef FinancingPermissionChecker = Future<bool> Function(
  String permissionKey,
);

/// Test seam: tests (and only tests) substitute the backend check. The default
/// is always the real `core.has_permission` call.
final financingPermissionCheckerProvider = Provider<FinancingPermissionChecker>((
  ref,
) {
  final repository = ref.watch(accessPolicyRepositoryProvider);
  return repository.hasPermission;
});

/// Resolves one permission key. The active entity context is derived by the
/// existing FAMHUB context mechanism — never supplied by the caller.
final financingPermissionProvider =
    FutureProvider.family<FinancingPermissionStatus, String>((
  ref,
  permissionKey,
) async {
  final context = ref.watch(contextProvider);

  if (context.isLoading) return FinancingPermissionStatus.loading;

  if (context.isGuest) {
    return const FinancingPermissionStatus(
      FinancingPermissionState.unavailable,
      'Sign in to check your Financing permissions.',
    );
  }

  final checkPermission = ref.watch(financingPermissionCheckerProvider);
  try {
    final allowed = await checkPermission(permissionKey);
    if (allowed) return FinancingPermissionStatus.allowed;

    return FinancingPermissionStatus(
      FinancingPermissionState.denied,
      'Permission "$permissionKey" is not granted for the active context.',
    );
  } catch (_) {
    return const FinancingPermissionStatus(
      FinancingPermissionState.unavailable,
      'Permissions are not available right now.',
    );
  }
});

/// Flattens the async resolution into a status the UI can branch on without
/// ever throwing or fabricating access.
final financingPermissionStatusProvider =
    Provider.family<FinancingPermissionStatus, String>((ref, permissionKey) {
  final async = ref.watch(financingPermissionProvider(permissionKey));
  return async.when(
    data: (status) => status,
    loading: () => FinancingPermissionStatus.loading,
    error: (_, __) => const FinancingPermissionStatus(
      FinancingPermissionState.unavailable,
      'Permissions are not available right now.',
    ),
  );
});

/// Combined "may I open the management surface" status for a set of keys.
/// Allowed when ANY of the keys is granted (each screen declares its own set).
final financingAnyPermissionStatusProvider =
    Provider.family<FinancingPermissionStatus, List<String>>((ref, keys) {
  final statuses = keys
      .map((k) => ref.watch(financingPermissionStatusProvider(k)))
      .toList(growable: false);

  if (statuses.any((s) => s.isAllowed)) return FinancingPermissionStatus.allowed;
  if (statuses.any((s) => s.isLoading)) return FinancingPermissionStatus.loading;
  if (statuses.any((s) => s.isUnavailable)) {
    return const FinancingPermissionStatus(
      FinancingPermissionState.unavailable,
      'Permissions are not available right now.',
    );
  }
  return const FinancingPermissionStatus(
    FinancingPermissionState.denied,
    'Catalogue management is not enabled for your role.',
  );
});
