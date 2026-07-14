/// ============================================================
/// ACCESS SDK — Public facade for access decisions
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// ✅ Responsibilities:
///   - Expose access decision checks to feature modules
///   - Delegate to runtimeDecisionEngineProvider
///   - Never expose AccessDecisionEngine directly
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain persistence logic
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/runtime_decision/domain/runtime_request.dart';
import 'package:famhub_app/core/runtime_decision/domain/runtime_decision.dart';
import 'package:famhub_app/core/runtime_decision/application/runtime_decision_provider.dart';
import 'api/sdk_annotations.dart';

/// ============================================================
/// ACCESS SDK
/// ============================================================
///
/// Feature modules use this instead of reading providers directly.
///
/// Usage:
///   final access = ref.read(famhubAccessSdkProvider);
///   if (access.canAccess('marketplace', 'listings')) { ... }
///   if (access.canPerform('marketplace', 'create')) { ... }
///   final decision = access.decision('marketplace', 'navigate');
/// ============================================================

@PublicSdk()
class AccessSdk {
  final Ref _ref;

  AccessSdk(this._ref);

  /// Check if the user can access a resource in a module
  @sdkMethod(version: '1.0.0')
  bool canAccess(String module, String resource) =>
      _ref.read(canRenderProvider((module, resource)));

  /// Check if the user can perform an action in a module
  @sdkMethod(version: '1.0.0')
  bool canPerform(String module, String action) =>
      _ref.read(canExecuteProvider((module, action)));

  /// Get the full runtime decision for a navigation request
  @sdkMethod(version: '1.0.0')
  RuntimeDecision decision(String module, String action) {
    return _ref.read(runtimeDecisionProvider(
      RuntimeRequest(
        action: action,
        module: module,
        capability: '$module.$action',
        policy: '$module.$action',
        permission: '$module.$action',
        featureFlag: '${module}_enabled',
      ),
    ));
  }

  /// Get the denial reason if access is denied
  @sdkMethod(version: '1.0.0')
  String? denyReason(String module, String action) {
    final d = decision(module, action);
    return d.allowed ? null : d.reason;
  }

  /// Check if navigation to a module is allowed
  @sdkMethod(version: '1.0.0')
  bool canNavigate(String module) =>
      _ref.read(canNavigateProvider(module));

  /// Check if the user can create in a module
  @sdkMethod(version: '1.0.0')
  bool canCreate(String module) =>
      _ref.read(canCreateProvider(module));

  /// Check if the user can edit in a module
  @sdkMethod(version: '1.0.0')
  bool canEdit(String module) =>
      _ref.read(canEditProvider(module));

  /// Check if the user can delete in a module
  @sdkMethod(version: '1.0.0')
  bool canDelete(String module) =>
      _ref.read(canDeleteProvider(module));

  /// Check if the user can approve in a module
  @sdkMethod(version: '1.0.0')
  bool canApprove(String module) =>
      _ref.read(canApproveProvider(module));

  /// Check if the user can purchase in a module
  @sdkMethod(version: '1.0.0')
  bool canPurchase(String module) =>
      _ref.read(canPurchaseProvider(module));

  /// Check if the user can sell in a module
  @sdkMethod(version: '1.0.0')
  bool canSell(String module) =>
      _ref.read(canSellProvider(module));

  /// Check if the user can export data
  @sdkMethod(version: '1.0.0')
  bool canExport(String module) =>
      _ref.read(canExportProvider(module));

  /// Check if the user can upload files
  @sdkMethod(version: '1.0.0')
  bool canUpload(String module) =>
      _ref.read(canUploadProvider(module));

  /// Check if the user can view analytics
  @sdkMethod(version: '1.0.0')
  bool canViewAnalytics(String module) =>
      _ref.read(canViewAnalyticsProvider(module));

  /// Check if the user can use AI features
  @sdkMethod(version: '1.0.0')
  bool canUseAI(String module) =>
      _ref.read(canUseAIProvider(module));

  /// Check if the user can manage staff
  @sdkMethod(version: '1.0.0')
  bool canManageStaff(String module) =>
      _ref.read(canManageStaffProvider(module));

  /// Check if the user can access workflows
  @sdkMethod(version: '1.0.0')
  bool canAccessWorkflow(String module) =>
      _ref.read(canAccessWorkflowProvider(module));
}

/// ============================================================
/// PROVIDER: ACCESS SDK

@SdkProvider()
final famhubAccessSdkProvider = Provider<AccessSdk>((ref) {
  return AccessSdk(ref);
});
