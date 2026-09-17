/// ============================================================
/// ADMIN CAPABILITY PROVIDERS — RUNTIME BRIDGE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Resolve the active entity context (contextProvider) for Admin.
///   - Resolve each capability descriptor against the canonical
///     backend authorization function `core.has_permission(p_permission)`.
///   - Expose a safe loading / unavailable / allowed / denied state.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - No permission is granted here. When the backend does not
///     explicitly allow a capability, it is NOT rendered.
///   - When permission data is unavailable, the state is `unavailable`
///     so the UI can show a locked state instead of fabricating access.
///   - No new role registry, context provider, or dashboard engine.
///
/// ❌ Does NOT:
///   - Grant or persist permissions.
///   - Contain UI.
///   - Perform management operations.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/access/application/providers/access_policy_provider.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_capability.dart';

/// ============================================================
/// CAPABILITY STATE
/// ============================================================
enum AdminCapabilityState {
  /// Context/permission data is still resolving.
  loading,

  /// Permission data is not available — render a locked state.
  unavailable,

  /// The backend/runtime explicitly allowed the capability.
  allowed,

  /// The backend/runtime explicitly denied the capability.
  denied,
}

/// Resolved status of a single admin capability.
class AdminCapabilityStatus {
  final AdminCapabilityState state;
  final String? reason;

  const AdminCapabilityStatus(this.state, [this.reason]);

  bool get isAllowed => state == AdminCapabilityState.allowed;
  bool get isLoading => state == AdminCapabilityState.loading;
  bool get isUnavailable => state == AdminCapabilityState.unavailable;

  static const AdminCapabilityStatus loading =
      AdminCapabilityStatus(AdminCapabilityState.loading);
  static const AdminCapabilityStatus allowed =
      AdminCapabilityStatus(AdminCapabilityState.allowed);
}

/// ============================================================
/// PROVIDER: ADMIN WORKSPACE ACCESS (BASE GATE)
/// ============================================================
///
/// Whether the active context may open the Admin workspace at all.
/// This does NOT grant any section — it only verifies that an
/// authenticated entity context and active role exist. Per-capability
/// authority is resolved by `adminCapabilityStatusProvider` through the
/// backend `core.has_permission` function.
/// ============================================================
final adminWorkspaceAccessProvider = Provider<AdminCapabilityStatus>((ref) {
  final context = ref.watch(contextProvider);

  if (context.isLoading) return AdminCapabilityStatus.loading;

  if (context.isGuest) {
    return const AdminCapabilityStatus(
      AdminCapabilityState.unavailable,
      'Sign in with an organisation account to open administration.',
    );
  }

  if (context.role == null || context.role!.isEmpty) {
    return const AdminCapabilityStatus(
      AdminCapabilityState.unavailable,
      'No active role is available for administration.',
    );
  }

  return AdminCapabilityStatus.allowed;
});

/// ============================================================
/// PROVIDER: SINGLE ADMIN CAPABILITY STATUS
/// ============================================================
///
/// Resolves one backend permission key through the canonical
/// `core.has_permission` function. The base gate must pass first.
/// The backend authorization result is authoritative — no grant is
/// ever inferred client-side.
/// ============================================================
final adminCapabilityStatusProvider =
    FutureProvider.family<AdminCapabilityStatus, String>((ref, permissionKey) async {
  final base = ref.watch(adminWorkspaceAccessProvider);
  if (!base.isAllowed) return base;

  final repository = ref.watch(accessPolicyRepositoryProvider);
  try {
    final allowed = await repository.hasPermission(permissionKey);
    if (allowed) return AdminCapabilityStatus.allowed;

    return AdminCapabilityStatus(
      AdminCapabilityState.denied,
      'Permission "$permissionKey" is not granted for the active context.',
    );
  } catch (_) {
    return const AdminCapabilityStatus(
      AdminCapabilityState.unavailable,
      'Administration permissions are not available right now.',
    );
  }
});

/// ============================================================
/// AGGREGATE ADMIN DASHBOARD ACCESS
/// ============================================================
class AdminDashboardAccess {
  final AdminCapabilityState state;
  final List<AdminCapability> platformCapabilities;
  final List<AdminCapability> entityCapabilities;
  final String? reason;

  const AdminDashboardAccess({
    required this.state,
    this.platformCapabilities = const [],
    this.entityCapabilities = const [],
    this.reason,
  });

  bool get isLoading => state == AdminCapabilityState.loading;
  bool get isAllowed => state == AdminCapabilityState.allowed;
  bool get hasAnyCapability =>
      platformCapabilities.isNotEmpty || entityCapabilities.isNotEmpty;

  static const AdminDashboardAccess loading = AdminDashboardAccess(
    state: AdminCapabilityState.loading,
  );
}

/// ============================================================
/// PROVIDER: ADMIN DASHBOARD ACCESS
/// ============================================================
///
/// Filters the capability descriptors down to those the active
/// context is explicitly allowed by the backend. Platform and entity
/// layers are kept separate — holding one never implies the other.
/// ============================================================
final adminDashboardAccessProvider = Provider<AdminDashboardAccess>((ref) {
  final base = ref.watch(adminWorkspaceAccessProvider);
  if (base.isLoading) return AdminDashboardAccess.loading;
  if (!base.isAllowed) {
    return AdminDashboardAccess(
      state: base.state,
      reason: base.reason,
    );
  }

  final platform = <AdminCapability>[];
  final entity = <AdminCapability>[];
  var loading = false;
  String? unavailableReason;

  for (final capability in AdminCapabilityCatalog.platform) {
    final status = _resolveStatus(ref, capability.permissionKey);
    if (status.isAllowed) {
      platform.add(capability);
    } else if (status.isLoading) {
      loading = true;
    } else if (status.isUnavailable) {
      unavailableReason ??= status.reason;
    }
  }

  for (final capability in AdminCapabilityCatalog.entity) {
    final status = _resolveStatus(ref, capability.permissionKey);
    if (status.isAllowed) {
      entity.add(capability);
    } else if (status.isLoading) {
      loading = true;
    } else if (status.isUnavailable) {
      unavailableReason ??= status.reason;
    }
  }

  if (platform.isEmpty && entity.isEmpty) {
    if (loading) return AdminDashboardAccess.loading;
    if (unavailableReason != null) {
      return AdminDashboardAccess(
        state: AdminCapabilityState.unavailable,
        reason: unavailableReason,
      );
    }
  }

  return AdminDashboardAccess(
    state: AdminCapabilityState.allowed,
    platformCapabilities: platform,
    entityCapabilities: entity,
  );
});

AdminCapabilityStatus _resolveStatus(Ref ref, String permissionKey) {
  final async = ref.watch(adminCapabilityStatusProvider(permissionKey));
  return async.when(
    data: (status) => status,
    loading: () => AdminCapabilityStatus.loading,
    error: (_, __) => const AdminCapabilityStatus(
      AdminCapabilityState.unavailable,
      'Administration permissions are not available right now.',
    ),
  );
}
