/// ============================================================
/// ACTIVE WORKSPACE PROVIDER — SINGLE SOURCE OF TRUTH
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/application/ = application layer
///
/// EVERY shell component reads `activeWorkspaceProvider` instead of
/// managing tabs, sidebar state, or navigation independently.
///
/// ✅ Responsibilities:
///   - Single source of truth for the active workspace
///   - Expose all workspace state: tabs, active tab, sidebar, layout
///   - Provide derived queries: activeTab, openTabs, recentTabs, etc.
///
/// ✅ Shell Integration:
///   The shell asks workspaceProvider for:
///   - Sidebar state
///   - Focused module
///   - Open tabs
///   - Secondary panel
///   - Workspace layout
///
/// ✅ Usage:
///   ```dart
///   final workspace = ref.watch(activeWorkspaceProvider);
///   final activeTab = ref.watch(activeTabProvider);
///   final openTabs = ref.watch(openTabsProvider);
///   ```
///
/// ❌ Does NOT:
///   - Contain UI
///   - Contain database logic
///   - Replace backend tables
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/workspace/domain/workspace_data.dart';
import 'package:famhub_app/core/workspace/domain/workspace_tab.dart';
import 'package:famhub_app/core/workspace/domain/workspace_layout.dart';
import 'package:famhub_app/core/workspace/domain/workspace_snapshot.dart';
import 'package:famhub_app/core/workspace/application/workspace_engine.dart';
import 'package:famhub_app/core/workspace/application/workspace_provider.dart';

/// ============================================================
/// ACTIVE WORKSPACE NOTIFIER
/// ============================================================
///
/// Manages the active workspace state and delegates all
/// mutations to the WorkspaceEngine.
/// ============================================================
class ActiveWorkspaceNotifier extends Notifier<Workspace> {
  @override
  Workspace build() {
    // Start with a default empty workspace
    return const Workspace(
      workspaceId: 'workspace-default-001',
      displayName: 'Default Workspace',
    );
  }

  /// ============================================================
  /// INIT
  /// ============================================================
  ///
  /// Load the active workspace from storage.
  /// Called on app startup and login.
  /// ============================================================
  Future<void> init() async {
    final engine = ref.read(workspaceEngineProvider);
    final snapshot =
        await _loadFromStorage(engine, 'workspace-default-001');
    if (snapshot != null) {
      state = Workspace.fromSnapshot(snapshot);
    }
  }

  /// ============================================================
  /// OPEN TAB
  /// ============================================================
  void openTab(WorkspaceTab tab) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.openTab(state, tab);
  }

  /// ============================================================
  /// CLOSE TAB
  /// ============================================================
  void closeTab(String tabId, {bool force = false}) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.closeTab(state, tabId, force: force);
  }

  /// ============================================================
  /// PIN TAB
  /// ============================================================
  void pinTab(String tabId) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.pinTab(state, tabId);
  }

  /// ============================================================
  /// UNPIN TAB
  /// ============================================================
  void unpinTab(String tabId) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.unpinTab(state, tabId);
  }

  /// ============================================================
  /// FOCUS TAB
  /// ============================================================
  void focusTab(String tabId) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.focusTab(state, tabId);
  }

  /// ============================================================
  /// REORDER TABS
  /// ============================================================
  void reorderTabs(List<String> tabIdsInOrder) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.reorderTabs(state, tabIdsInOrder);
  }

  /// ============================================================
  /// OPEN RECENT
  /// ============================================================
  void openRecent() {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.openRecent(state);
  }

  /// ============================================================
  /// SWITCH WORKSPACE
  /// ============================================================
  Future<void> switchWorkspace(String workspaceId) async {
    final engine = ref.read(workspaceEngineProvider);
    state = await engine.switchWorkspace(state, workspaceId);
  }

  /// ============================================================
  /// SAVE WORKSPACE
  /// ============================================================
  Future<void> saveWorkspace() async {
    final engine = ref.read(workspaceEngineProvider);
    await engine.saveWorkspace(state);
  }

  /// ============================================================
  /// RESTORE WORKSPACE
  /// ============================================================
  Future<void> restoreWorkspace(String workspaceId) async {
    final engine = ref.read(workspaceEngineProvider);
    state = await engine.restoreWorkspace(state, workspaceId);
  }

  /// ============================================================
  /// CLEAR WORKSPACE
  /// ============================================================
  void clearWorkspace() {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.clearWorkspace(state);
  }

  /// ============================================================
  /// NAVIGATION HISTORY
  /// ============================================================
  void navigateBack() {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.navigateBack(state);
  }

  void navigateForward() {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.navigateForward(state);
  }

  /// ============================================================
  /// SIDEBAR STATE
  /// ============================================================
  void toggleSidebar() {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.toggleSidebar(state);
  }

  void setSidebarExpanded(bool expanded) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.setSidebarExpanded(state, expanded);
  }

  void setSidebarVisible(bool visible) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.setSidebarVisible(state, visible);
  }

  void setFocusedModule(String? moduleKey) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.setFocusedModule(state, moduleKey);
  }

  /// ============================================================
  /// SHELL / LAYOUT MODE
  /// ============================================================
  void setShellMode(ShellLayoutMode mode) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.setShellMode(state, mode);
  }

  void setSecondaryPanel(bool visible, {double? width}) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.setSecondaryPanel(state, visible: visible, width: width);
  }

  /// ============================================================
  /// HISTORY RECORDING
  /// ============================================================
  void recordCommand(String commandActionKey) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.recordCommand(state, commandActionKey);
  }

  void recordQuickAction(String actionKey) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.recordQuickAction(state, actionKey);
  }

  /// ============================================================
  /// MISCELLANEOUS
  /// ============================================================
  void setLastDashboard(String? route) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.setLastDashboard(state, route);
  }

  void setWindowMode(WindowMode mode) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.setWindowMode(state, mode);
  }

  void setOrganization(String? organizationId) {
    final engine = ref.read(workspaceEngineProvider);
    state = engine.setOrganization(state, organizationId: organizationId);
  }

  /// ============================================================
  /// LOAD ORGANIZATION WORKSPACE
  /// ============================================================
  ///
  /// Called when switching organizations to restore that
  /// organization's last workspace.
  /// ============================================================
  Future<void> loadOrganizationWorkspace(String organizationId) async {
    final engine = ref.read(workspaceEngineProvider);
    final workspace =
        await engine.loadOrganizationWorkspace(organizationId);
    if (workspace != null) {
      state = workspace;
    }
  }

  /// ============================================================
  /// CLEAR
  /// ============================================================
  ///
  /// Reset to empty workspace on logout.
  /// ============================================================
  void clear() {
    state = const Workspace(
      workspaceId: 'workspace-default-001',
      displayName: 'Default Workspace',
    );
  }

  /// ============================================================
  /// HELPERS
  /// ============================================================
  Future<WorkspaceSnapshot?> _loadFromStorage(
    WorkspaceEngine engine,
    String workspaceId,
  ) async {
    // Use the engine to restore. If restored workspace differs
    // from current, return its snapshot.
    final restored = await engine.restoreWorkspace(state, workspaceId);
    if (restored.workspaceId != state.workspaceId || restored.hasTabs) {
      return restored.captureSnapshot();
    }
    return null;
  }
}

/// ============================================================
/// PROVIDER: ACTIVE WORKSPACE
/// ============================================================
///
/// EVERY shell component uses this provider to read the active workspace.
///
/// ✅ Usage:
///   ```dart
///   final workspace = ref.watch(activeWorkspaceProvider);
///
///   // Access workspace properties
///   final hasTabs = workspace.hasTabs;
///   final activeTab = workspace.activeTab;
///   final sidebarState = workspace.sidebar;
///   ```
/// ============================================================
final activeWorkspaceProvider =
    NotifierProvider<ActiveWorkspaceNotifier, Workspace>(
  ActiveWorkspaceNotifier.new,
);

// ============================================================
// DERIVED PROVIDERS
// ============================================================

/// ============================================================
/// PROVIDER: ACTIVE TAB
/// ============================================================
///
/// The currently focused tab. Null if no tabs are open.
/// ============================================================
final activeTabProvider = Provider<WorkspaceTab?>((ref) {
  return ref.watch(activeWorkspaceProvider).activeTab;
});

/// ============================================================
/// PROVIDER: OPEN TABS
/// ============================================================
///
/// All currently open tabs in the workspace.
/// ============================================================
final openTabsProvider = Provider<List<WorkspaceTab>>((ref) {
  return ref.watch(activeWorkspaceProvider).tabs;
});

/// ============================================================
/// PROVIDER: RECENT TABS
/// ============================================================
///
/// Recently closed tab IDs (for undo close).
/// ============================================================
final recentTabsProvider = Provider<List<String>>((ref) {
  return ref.watch(activeWorkspaceProvider).recentTabIds;
});

/// ============================================================
/// PROVIDER: WORKSPACE HISTORY
/// ============================================================
///
/// Navigation history for the active workspace.
/// ============================================================
final workspaceHistoryProvider = Provider<NavigationHistory>((ref) {
  return ref.watch(activeWorkspaceProvider).history;
});

/// ============================================================
/// PROVIDER: SIDEBAR STATE
/// ============================================================
///
/// Sidebar state for the active workspace.
/// ============================================================
final sidebarStateProvider = Provider<SidebarState>((ref) {
  return ref.watch(activeWorkspaceProvider).sidebar;
});

/// ============================================================
/// PROVIDER: WORKSPACE SNAPSHOT
/// ============================================================
///
/// A serializable snapshot of the current workspace state.
/// Ready for future persistence to Supabase.
/// ============================================================
final workspaceSnapshotProvider = Provider<WorkspaceSnapshot>((ref) {
  return ref.watch(activeWorkspaceProvider).captureSnapshot();
});

/// ============================================================
/// PROVIDER: WORKSPACE LAYOUT
/// ============================================================
///
/// The current workspace layout configuration.
/// ============================================================
final workspaceLayoutProvider = Provider<WorkspaceLayout>((ref) {
  return ref.watch(activeWorkspaceProvider).layout;
});

/// ============================================================
/// PROVIDER: WORKSPACE SHELL MODE
/// ============================================================
///
/// The current shell layout mode.
/// ============================================================
final workspaceShellModeProvider = Provider<ShellLayoutMode>((ref) {
  return ref.watch(activeWorkspaceProvider).shellMode;
});

/// ============================================================
/// PROVIDER: ACTIVE MODULE KEY
/// ============================================================
///
/// The module key of the currently active tab.
/// Useful for AI context and shell state queries.
/// ============================================================
final activeModuleKeyProvider = Provider<String?>((ref) {
  return ref.watch(activeWorkspaceProvider).activeModuleKey;
});

/// ============================================================
/// PROVIDER: SECONDARY PANEL STATE
/// ============================================================
///
/// Whether the secondary panel is visible.
/// ============================================================
final secondaryPanelVisibleProvider = Provider<bool>((ref) {
  final workspace = ref.watch(activeWorkspaceProvider);
  return workspace.layout.secondaryPanelVisible;
});

/// ============================================================
/// PROVIDER: COMMAND PALETTE HISTORY
/// ============================================================
///
/// Recent command palette action keys.
/// ============================================================
final commandPaletteHistoryProvider = Provider<List<String>>((ref) {
  return ref.watch(activeWorkspaceProvider).commandPaletteHistory;
});

/// ============================================================
/// PROVIDER: QUICK ACTIONS HISTORY
/// ============================================================
///
/// Recent quick actions history keys.
/// ============================================================
final quickActionsHistoryProvider = Provider<List<String>>((ref) {
  return ref.watch(activeWorkspaceProvider).quickActionsHistory;
});
