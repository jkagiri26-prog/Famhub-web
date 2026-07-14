library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/sdk_annotations.dart';
import 'api/sdk_version.dart';
import 'navigation_sdk.dart';
import 'organization_sdk.dart';
import 'workspace_sdk.dart';
import 'capability_sdk.dart';
import 'policy_sdk.dart';
import 'access_sdk.dart';
import 'workflow_sdk.dart';
import 'dashboard_sdk.dart';
import 'notification_sdk.dart';
import 'shell_sdk.dart';
import 'ai_context_sdk.dart';
import 'spatial_sdk.dart';

/// ============================================================
/// FAMHUB SDK
/// ============================================================
///
/// Groups all domain SDKs into a single entry point.
///
/// This is the ONLY public API that feature modules should consume.
/// Internal runtime architecture (providers, engines, bridges)
/// should remain hidden from feature modules.
/// ============================================================
@PublicSdk()
class FamhubSdk {
  /// Navigation — route management
  final NavigationSdk navigation;

  /// Organization — active org context
  final OrganizationSdk organization;

  /// Workspace — tabs, layout, sidebar
  final WorkspaceSdk workspace;

  /// Capabilities — operational permissions
  final CapabilitySdk capabilities;

  /// Policy — location-based rules
  final PolicySdk policy;

  /// Access — unified access decisions
  final AccessSdk access;

  /// Workflow — workflow execution
  final WorkflowSdk workflow;

  /// Dashboard — composition state
  final DashboardSdk dashboard;

  /// Notifications — alert system
  final NotificationSdk notifications;

  /// Shell — layout modes, sidebar, theme
  final ShellSdk shell;

  /// AI Context — unified context for AI features
  final AiContextSdk ai;

  /// Spatial — spatial assets, boundaries, GPS capture
  final SpatialSdk spatial;

  const FamhubSdk({
    required this.navigation,
    required this.organization,
    required this.workspace,
    required this.capabilities,
    required this.policy,
    required this.access,
    required this.workflow,
    required this.dashboard,
    required this.notifications,
    required this.shell,
    required this.ai,
    required this.spatial,
  });
}

/// ============================================================
/// PROVIDER: FAMHUB SDK
/// ============================================================
///
/// The single provider that exposes the entire SDK.
///
/// Usage:
///   final sdk = ref.read(famhubSdkProvider);
///   sdk.navigation.go(context, '/farm');
///   sdk.workspace.openTab(tab);
///   sdk.spatial.selectAsset(asset);
///   sdk.spatial.area();
/// ============================================================
@SdkProvider()
final famhubSdkProvider = Provider<FamhubSdk>((ref) {
  return FamhubSdk(
    navigation: NavigationSdk(ref),
    organization: OrganizationSdk(ref),
    workspace: WorkspaceSdk(ref),
    capabilities: CapabilitySdk(ref),
    policy: PolicySdk(ref),
    access: AccessSdk(ref),
    workflow: WorkflowSdk(ref),
    dashboard: DashboardSdk(ref),
    notifications: NotificationSdk(ref),
    shell: ShellSdk(ref),
    ai: AiContextSdk(ref),
    spatial: SpatialSdk(ref),
  );
});

