/// ============================================================
/// WORKSPACE SDK — Public facade for workspace runtime
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// ✅ Responsibilities:
///   - Expose workspace state and operations to feature modules
///   - Delegate to activeWorkspaceProvider
///   - Never expose WorkspaceEngine directly
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain persistence logic
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/workspace/domain/workspace_data.dart';
import 'package:famhub_app/core/workspace/domain/workspace_tab.dart';
import 'package:famhub_app/core/workspace/domain/workspace_layout.dart';
import 'package:famhub_app/core/workspace/domain/workspace_snapshot.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'api/sdk_annotations.dart';

/// ============================================================
/// WORKSPACE SDK
/// ============================================================
///
/// Feature modules use this instead of reading providers directly.
///
/// Usage:
///   final ws = ref.read(famhubWorkspaceSdkProvider);
///   ws.openTab(tab);
///   ws.closeTab('tab-123');
///   final activeTab = ws.currentModule();
/// ============================================================
@publicSdk()
class WorkspaceSdk {
  final Ref _ref;

  WorkspaceSdk(this._ref);

  /// The current workspace (snapshot)
  Workspace get _ws => _ref.read(activeWorkspaceProvider);

  /// The notifier for mutations
  ActiveWorkspaceNotifier get _notifier =>
      _ref.read(activeWorkspaceProvider.notifier);

  /// The current workspace (reactive)
  @SdkMethod(version: '1.0.0')
  Workspace watch() => _ref.watch(activeWorkspaceProvider);

  /// Open a new tab (or focus existing one with same moduleKey + route)
  @SdkMethod(version: '1.0.0')
  void openTab(WorkspaceTab tab) => _notifier.openTab(tab);

  /// Close a tab by its ID
  @SdkMethod(version: '1.0.0')
  void closeTab(String tabId, {bool force = false}) =>
      _notifier.closeTab(tabId, force: force);

  /// Focus a tab by its ID
  @SdkMethod(version: '1.0.0')
  void focusTab(String tabId) => _notifier.focusTab(tabId);

  /// Pin a tab so it survives workspace clearing
  @SdkMethod(version: '1.0.0')
  void pinTab(String tabId) => _notifier.pinTab(tabId);

  /// Unpin a tab
  @SdkMethod(version: '1.0.0')
  void unpinTab(String tabId) => _notifier.unpinTab(tabId);

  /// Reorder tabs via drag-and-drop
  @SdkMethod(version: '1.0.0')
  void reorderTabs(List<String> tabIdsInOrder) =>
      _notifier.reorderTabs(tabIdsInOrder);

  /// Reopen the most recently closed tab
  @SdkMethod(version: '1.0.0')
  void openRecent() => _notifier.openRecent();

  /// Switch to a different workspace
  @SdkMethod(version: '1.0.0')
  Future<void> switchWorkspace(String workspaceId) =>
      _notifier.switchWorkspace(workspaceId);

  /// Save the current workspace to storage
  @SdkMethod(version: '1.0.0')
  Future<void> saveWorkspace() => _notifier.saveWorkspace();

  /// Restore a workspace from storage
  @SdkMethod(version: '1.0.0')
  Future<void> restoreWorkspace(String workspaceId) =>
      _notifier.restoreWorkspace(workspaceId);

  /// Clear all non-pinned tabs
  @SdkMethod(version: '1.0.0')
  void clearWorkspace() => _notifier.clearWorkspace();

  /// Navigate backward in history
  @SdkMethod(version: '1.0.0')
  void navigateBack() => _notifier.navigateBack();

  /// Navigate forward in history
  @SdkMethod(version: '1.0.0')
  void navigateForward() => _notifier.navigateForward();

  /// Get the current workspace ID
  @SdkMethod(version: '1.0.0')
  String currentWorkspaceId() => _ws.workspaceId;

  /// Get the current workspace
  @SdkMethod(version: '1.0.0')
  Workspace currentWorkspace() => _ws;

  /// Get the active tab's module key
  @SdkMethod(version: '1.0.0')
  String? currentModule() => _ws.activeModuleKey;

  /// Get the active tab
  @SdkMethod(version: '1.0.0')
  WorkspaceTab? activeTab() => _ws.activeTab;

  /// Get all open tabs
  @SdkMethod(version: '1.0.0')
  List<WorkspaceTab> openTabs() => _ws.tabs;

  /// Check if the workspace has any open tabs
  @SdkMethod(version: '1.0.0')
  bool hasTabs() => _ws.hasTabs;

  /// Get the sidebar expanded state
  @SdkMethod(version: '1.0.0')
  bool sidebarExpanded() => _ws.sidebar.isExpanded;

  /// Get the secondary panel visibility
  @SdkMethod(version: '1.0.0')
  bool secondaryPanelVisible() => _ws.layout.secondaryPanelVisible;

  /// Set window mode
  @SdkMethod(version: '1.0.0')
  void setWindowMode(WindowMode mode) => _notifier.setWindowMode(mode);

  /// Get the current window mode
  @SdkMethod(version: '1.0.0')
  WindowMode windowMode() => _ws.windowMode;

  /// Get the current shell layout mode
  @SdkMethod(version: '1.0.0')
  ShellLayoutMode shellMode() => _ws.shellMode;

  /// Set the shell layout mode
  @SdkMethod(version: '1.0.0')
  void setShellMode(ShellLayoutMode mode) => _notifier.setShellMode(mode);
}

/// ============================================================
/// PROVIDER: WORKSPACE SDK
/// ============================================================
@SdkProvider()
final famhubWorkspaceSdkProvider = Provider<WorkspaceSdk>((ref) {
  return WorkspaceSdk(ref);
});
