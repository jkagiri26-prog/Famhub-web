/// ============================================================
/// ADMIN CAPABILITY PROVIDERS — RUNTIME BRIDGE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Resolve the active entity context (contextProvider) for Admin.
///   - Resolve each capability descriptor against the EXISTING
///     permission infrastructure (backend access policy +
///     RuntimeDecisionEngine).
///   - Expose a safe loading / unavailable / allowed / denied state.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - No permission is granted here. When the backend/runtime does
///     not explicitly allow a capability, it is NOT rendered.
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
import 'package:famhub_app/core/runtime_decision/application/runtime_decision_provider.dart';
import 'package:famhub_app/core/runtime_decision/domain/runtime_reason.dart';
import 'package:famhub_app/core/runtime_decision/domain/runtime_request.dart';
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
/// authenticated entity context and permission data exist.
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

  final policyAsync = ref.watch(accessPolicyProvider);
  if (policyAsync.isLoading) return AdminCapabilityStatus.loading;
  if (policyAsync.hasError) {
    return const AdminCapabilityStatus(
      AdminCapabilityState.unavailable,
      'Administration permissions are not available right now.',
    );
  }

  return AdminCapabilityStatus.allowed;
});

/// ============================================================
/// PROVIDER: SINGLE ADMIN CAPABILITY STATUS
/// ============================================================
///
/// Evaluates one backend permission key through the existing
/// RuntimeDecisionEngine. The base gate must pass first.
/// ============================================================
final adminCapabilityStatusProvider =
    Provider.family<AdminCapabilityStatus, String>((ref, permissionKey) {
  final base = ref.watch(adminWorkspaceAccessProvider);
  if (!base.isAllowed) return base;

  final decision = ref.watch(runtimeDecisionProvider(RuntimeRequest(
    action: 'view',
    module: 'admin_console',
    permission: permissionKey,
  )));

  if (decision.allowed) return AdminCapabilityStatus.allowed;

  if (decision.failedChecks.contains(RuntimeCheckCodes.ENGINE_NOT_AVAILABLE) ||
      decision.failedChecks
          .contains(RuntimeCheckCodes.ACCESS_POLICY_NOT_LOADED)) {
    return const AdminCapabilityStatus(
      AdminCapabilityState.unavailable,
      'Administration permissions are not available right now.',
    );
  }

  return AdminCapabilityStatus(AdminCapabilityState.denied, decision.reason);
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
/// context is explicitly allowed. Platform and entity layers are
/// kept separate — holding one never implies the other.
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

  final platform = <AdminCapability>[
    for (final capability in AdminCapabilityCatalog.platform)
      if (ref
          .watch(adminCapabilityStatusProvider(capability.permissionKey))
          .isAllowed)
        capability,
  ];

  final entity = <AdminCapability>[
    for (final capability in AdminCapabilityCatalog.entity)
      if (ref
          .watch(adminCapabilityStatusProvider(capability.permissionKey))
          .isAllowed)
        capability,
  ];

  return AdminDashboardAccess(
    state: AdminCapabilityState.allowed,
    platformCapabilities: platform,
    entityCapabilities: entity,
  );
});
