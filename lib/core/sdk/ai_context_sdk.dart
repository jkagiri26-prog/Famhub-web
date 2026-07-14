/// ============================================================
/// AI CONTEXT SDK — Public facade for AI context queries
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// ✅ Responsibilities:
///   - Expose a unified context snapshot for AI features
///   - Aggregate state from workspace, organization, and navigation
///   - Provide a single interface for AI assistants to understand
///     the current application state
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain persistence logic
///   - Contain UI
///
/// 🔮 Future:
///   AI features (recommendations, automation, assistant)
///   should consume ONLY this SDK for context awareness.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/organization_runtime/application/active_organization_provider.dart';
import 'package:famhub_app/core/organization_runtime/domain/organization_context.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/core/workspace/domain/workspace_data.dart';
import 'package:famhub_app/core/workspace/domain/workspace_tab.dart';
import 'package:famhub_app/core/spatial/application/spatial_engine.dart';
import 'package:famhub_app/core/spatial/application/spatial_provider.dart';
import 'package:famhub_app/core/spatial/domain/spatial_asset.dart';
import 'api/sdk_annotations.dart';

/// ============================================================
/// AI CONTEXT — Snapshot of current app state for AI
/// ============================================================
///
/// This is a value object that captures everything an AI
/// assistant needs to know about the current application state.
/// ============================================================
class AiContext {
  /// The current organization
  final OrganizationContext organization;

  /// The current workspace
  final Workspace workspace;

  /// The active tab, if any
  final WorkspaceTab? activeTab;

  /// The current module key
  final String? currentModule;

  /// The currently selected entity ID, if any
  final String? selectedEntity;

  /// Navigation history (routes visited)
  final List<String> navigationHistory;

  /// Command palette history
  final List<String> commandHistory;

  /// Quick actions history
  final List<String> quickActionsHistory;

  // ── Spatial Context (AI integration) ──

  /// The currently selected spatial asset (farm, field, block)
  final SpatialAsset? selectedSpatialAsset;

  /// The current boundary ID
  final String? boundaryId;

  /// The current capture session ID (if active)
  final String? captureSession;

  /// The asset area in hectares
  final double? area;

  /// The type of selected asset
  final String? assetType;

  /// The parent asset of the selected asset
  final String? parentAsset;

  const AiContext({
    required this.organization,
    required this.workspace,
    this.activeTab,
    this.currentModule,
    this.selectedEntity,
    this.navigationHistory = const [],
    this.commandHistory = const [],
    this.quickActionsHistory = const [],
    this.selectedSpatialAsset,
    this.boundaryId,
    this.captureSession,
    this.area,
    this.assetType,
    this.parentAsset,
  });
}

/// ============================================================
/// AI CONTEXT SDK
/// ============================================================
///
/// Feature modules and AI assistants use this for context.
///
/// Usage:
///   final ai = ref.read(famhubAiContextSdkProvider);
///   final ctx = ai.snapshot();
///   final org = ai.currentOrganization();
///   final module = ai.currentModule();
/// ============================================================
@PublicSdk()
class AiContextSdk {
  final Ref _ref;

  AiContextSdk(this._ref);

  /// Get a complete snapshot of the current AI context
  @SdkMethod(version: '1.0.0')
  AiContext snapshot() {
    final org = _ref.read(activeOrganizationProvider);
    final ws = _ref.read(activeWorkspaceProvider);
    final engine = _ref.read(spatialEngineProvider);

    return AiContext(
      organization: org,
      workspace: ws,
      activeTab: ws.activeTab,
      currentModule: ws.activeModuleKey,
      selectedEntity: ws.activeTab?.metadata?['entityId'] as String?,
      navigationHistory: List.from(ws.navigationHistory),
      commandHistory: List.from(ws.commandPaletteHistory),
      quickActionsHistory: List.from(ws.quickActionsHistory),
      // Spatial context
      selectedSpatialAsset: engine.currentAsset,
      boundaryId: engine.boundaryId,
      captureSession: engine.captureSessionId,
      area: engine.currentAreaHa ?? engine.calculateArea(),
      assetType: engine.currentAssetType,
      parentAsset: engine.currentParentAssetId,
    );
  }

  /// Get the current organization context
  @SdkMethod(version: '1.0.0')
  OrganizationContext currentOrganization() =>
      _ref.read(activeOrganizationProvider);

  /// Get the current workspace
  @SdkMethod(version: '1.0.0')
  Workspace currentWorkspace() =>
      _ref.read(activeWorkspaceProvider);

  /// Get the current module key (from active tab)
  @SdkMethod(version: '1.0.0')
  String? currentModule() =>
      _ref.read(activeWorkspaceProvider).activeModuleKey;

  /// Get the active tab
  @SdkMethod(version: '1.0.0')
  WorkspaceTab? activeTab() =>
      _ref.read(activeWorkspaceProvider).activeTab;

  /// Get the currently selected entity ID (if any, from tab metadata)
  @SdkMethod(version: '1.0.0')
  String? selectedEntity() {
    final tab = _ref.read(activeWorkspaceProvider).activeTab;
    // WorkspaceTab has no direct entityId field, use metadata
    return tab?.metadata?['entityId'] as String?;
  }

  /// Get the navigation history
  @SdkMethod(version: '1.0.0')
  List<String> navigationHistory() =>
      _ref.read(activeWorkspaceProvider).navigationHistory;

  /// Get the command palette history
  @SdkMethod(version: '1.0.0')
  List<String> commandHistory() =>
      _ref.read(activeWorkspaceProvider).commandPaletteHistory;

  /// Get the quick actions history
  @SdkMethod(version: '1.0.0')
  List<String> quickActionsHistory() =>
      _ref.read(activeWorkspaceProvider).quickActionsHistory;

  // ============================================================
  // SPATIAL CONTEXT METHODS
  // ============================================================

  /// Get the currently selected spatial asset
  @SdkMethod(version: '1.0.0')
  SpatialAsset? selectedSpatialAsset() =>
      _ref.read(spatialEngineProvider).currentAsset;

  /// Get the current boundary ID
  @SdkMethod(version: '1.0.0')
  String? boundaryId() =>
      _ref.read(spatialEngineProvider).boundaryId;

  /// Get the active capture session ID
  @SdkMethod(version: '1.0.0')
  String? captureSession() =>
      _ref.read(spatialEngineProvider).captureSessionId;

  /// Get the current asset area in hectares
  @SdkMethod(version: '1.0.0')
  double? area() {
    final engine = _ref.read(spatialEngineProvider);
    return engine.currentAreaHa ?? engine.calculateArea();
  }

  /// Get the current asset type
  @SdkMethod(version: '1.0.0')
  String? assetType() =>
      _ref.read(spatialEngineProvider).currentAssetType;

  /// Get the parent asset ID
  @SdkMethod(version: '1.0.0')
  String? parentAsset() =>
      _ref.read(spatialEngineProvider).currentParentAssetId;
}

/// ============================================================
/// PROVIDER: AI CONTEXT SDK
/// ============================================================
@SdkProvider()
final famhubAiContextSdkProvider = Provider<AiContextSdk>((ref) {
  return AiContextSdk(ref);
});
