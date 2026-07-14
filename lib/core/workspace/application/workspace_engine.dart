/// ============================================================
/// WORKSPACE ENGINE — CORE ORCHESTRATOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/application/ = application layer
///
/// The Workspace Engine is the central orchestrator for the
/// workspace runtime. It manages tabs, navigation, layout,
/// sidebar state, and workspace lifecycle.
///
/// ✅ Responsibilities:
///   - openTab()             — Open a new tab or focus existing one
///   - closeTab()            — Close a tab by ID
///   - pinTab()              — Pin a tab (survives clearing)
///   - unpinTab()            — Unpin a tab
///   - focusTab()            — Set a tab as active/focused
///   - reorderTabs()         — Reorder tabs via drag-and-drop
///   - openRecent()          — Reopen a recently closed tab
///   - switchWorkspace()     — Switch to a different workspace
///   - saveWorkspace()       — Persist the current workspace snapshot
///   - restoreWorkspace()    — Restore a workspace from snapshot
///   - clearWorkspace()      — Clear all non-pinned tabs
///   - navigateBack()        — Navigate backward in history
///   - navigateForward()     — Navigate forward in history
///   - toggleSidebar()       — Toggle sidebar expanded state
///   - setSidebarExpanded()  — Set sidebar expanded/collapsed
///   - setShellMode()        — Set the shell/layout mode
///   - setSecondaryPanel()   — Show/hide the secondary panel
///   - recordCommand()       — Record a command in palette history
///   - recordQuickAction()   — Record a quick action in history
///   - setLastDashboard()    — Set the last visited dashboard
///   - setWindowMode()       — Set the window mode
///
/// ❌ Does NOT:
///   - Contain UI
///   - Contain Flutter
///   - Hold state directly (state lives in Workspace model)
///
/// ✅ Architecture:
///   - All workspace logic lives here
///   - This is the SINGLE source of truth for workspace state mutations
///   - Delegates I/O to WorkspaceStorage
/// ============================================================
library;

import 'package:famhub_app/core/workspace/domain/workspace_data.dart';
import 'package:famhub_app/core/workspace/domain/workspace_tab.dart';
import 'package:famhub_app/core/workspace/domain/workspace_layout.dart';
import 'package:famhub_app/core/workspace/domain/workspace_snapshot.dart';
import 'package:famhub_app/core/workspace/infrastructure/workspace_storage.dart';

/// ============================================================
/// WORKSPACE ENGINE
/// ============================================================
///
/// Pure logic engine for workspace runtime operations.
/// All I/O is delegated to the storage layer.
/// ============================================================
class WorkspaceEngine {
  final WorkspaceStorage _storage;

  WorkspaceEngine({required WorkspaceStorage storage}) : _storage = storage;

  // ============================================================
  // TAB OPERATIONS
  // ============================================================

  /// ============================================================
  /// OPEN TAB
  /// ============================================================
  ///
  /// Opens a new tab or focuses an existing one if the module
  /// already has an open tab with the same route.
  ///
  /// Returns the updated workspace with the tab open and focused.
  ///
  /// If a tab with the same moduleKey and route already exists,
  /// it focuses that tab instead of creating a new one.
  /// ============================================================
  Workspace openTab(Workspace workspace, WorkspaceTab tab) {
    // Check if a tab with the same module key and route already exists
    final existingIndex = workspace.tabs.indexWhere(
      (t) => t.moduleKey == tab.moduleKey && t.route == tab.route,
    );

    if (existingIndex >= 0) {
      // Focus the existing tab
      final updatedTabs = [
        for (int i = 0; i < workspace.tabs.length; i++)
          if (i == existingIndex) workspace.tabs[i].touch() else workspace.tabs[i],
      ];

      return workspace.copyWith(
        tabs: updatedTabs,
        activeTabId: workspace.tabs[existingIndex].tabId,
        navigationHistory: _pushToHistory(
          workspace.navigationHistory,
          tab.route,
        ),
      );
    }

    // Create a new tab with a fresh timestamp
    final newTab = tab.copyWith(
      tabId: tab.tabId.isEmpty ? _generateTabId() : tab.tabId,
      lastAccessedAt: DateTime.now().millisecondsSinceEpoch,
    );

    return workspace.copyWith(
      tabs: [...workspace.tabs, newTab],
      activeTabId: newTab.tabId,
      navigationHistory: _pushToHistory(
        workspace.navigationHistory,
        tab.route,
      ),
    );
  }

  /// ============================================================
  /// CLOSE TAB
  /// ============================================================
  ///
  /// Closes a tab by its ID. Removes it from the open tabs list
  /// and adds it to the recent tabs list (for undo).
  ///
  /// If the closed tab was the active tab, focus switches to:
  ///   1. The nearest tab to its position
  ///   2. Any remaining tab
  ///   3. null (no active tab)
  ///
  /// Pinned tabs cannot be closed unless forced.
  /// ============================================================
  Workspace closeTab(Workspace workspace, String tabId,
      {bool force = false}) {
    // Find the tab
    final tabIndex = workspace.tabs.indexWhere((t) => t.tabId == tabId);
    if (tabIndex < 0) return workspace;

    final tab = workspace.tabs[tabIndex];

    // Respect pinned state unless forced
    if (tab.isPinned && !force) return workspace;

    // Remove the tab
    final updatedTabs = [
      for (int i = 0; i < workspace.tabs.length; i++)
        if (i != tabIndex) workspace.tabs[i],
    ];

    // Add to recent tabs (for undo close)
    final updatedRecent = [
      tabId,
      ...workspace.recentTabIds.where((id) => id != tabId),
    ];

    // If the active tab was closed, focus a different tab
    String? newActiveTabId = workspace.activeTabId;
    if (workspace.activeTabId == tabId) {
      if (updatedTabs.isNotEmpty) {
        // Try to focus the tab at the same index, or the last tab
        final focusIndex = tabIndex < updatedTabs.length
            ? tabIndex
            : updatedTabs.length - 1;
        newActiveTabId = updatedTabs[focusIndex].tabId;
      } else {
        newActiveTabId = null;
      }
    }

    return workspace.copyWith(
      tabs: updatedTabs,
      activeTabId: newActiveTabId,
      recentTabIds: updatedRecent,
    );
  }

  /// ============================================================
  /// PIN TAB
  /// ============================================================
  ///
  /// Pins a tab so it survives workspace clearing operations.
  /// ============================================================
  Workspace pinTab(Workspace workspace, String tabId) {
    final updatedPinned = [
      tabId,
      ...workspace.pinnedTabIds.where((id) => id != tabId),
    ];

    // Also update the tab's isPinned flag if it exists
    final updatedTabs = workspace.tabs.map((t) {
      if (t.tabId == tabId && !t.isPinned) {
        return t.copyWith(isPinned: true);
      }
      return t;
    }).toList();

    return workspace.copyWith(
      tabs: updatedTabs,
      pinnedTabIds: updatedPinned,
    );
  }

  /// ============================================================
  /// UNPIN TAB
  /// ============================================================
  ///
  /// Unpins a tab so it can be closed normally.
  /// ============================================================
  Workspace unpinTab(Workspace workspace, String tabId) {
    final updatedPinned = workspace.pinnedTabIds.where((id) => id != tabId).toList();

    final updatedTabs = workspace.tabs.map((t) {
      if (t.tabId == tabId && t.isPinned) {
        return t.copyWith(isPinned: false);
      }
      return t;
    }).toList();

    return workspace.copyWith(
      tabs: updatedTabs,
      pinnedTabIds: updatedPinned,
    );
  }

  /// ============================================================
  /// FOCUS TAB
  /// ============================================================
  ///
  /// Sets a tab as the active/focused tab.
  /// Returns the updated workspace.
  /// ============================================================
  Workspace focusTab(Workspace workspace, String tabId) {
    // Verify the tab exists
    final tabExists = workspace.tabs.any((t) => t.tabId == tabId);
    if (!tabExists) return workspace;

    final updatedTabs = workspace.tabs.map((t) {
      if (t.tabId == tabId) return t.touch();
      return t;
    }).toList();

    return workspace.copyWith(
      tabs: updatedTabs,
      activeTabId: tabId,
    );
  }

  /// ============================================================
  /// REORDER TABS
  /// ============================================================
  ///
  /// Reorders tabs via drag-and-drop. Accepts the new order
  /// as a list of tab IDs in the desired order.
  /// Returns the updated workspace.
  /// ============================================================
  Workspace reorderTabs(Workspace workspace, List<String> tabIdsInOrder) {
    // Build a lookup map for existing tabs
    final tabMap = {
      for (final tab in workspace.tabs) tab.tabId: tab,
    };

    // Create the new ordered list, preserving tabs not in the new order
    final reordered = <WorkspaceTab>[];
    final added = <String>{};

    for (final tabId in tabIdsInOrder) {
      if (tabMap.containsKey(tabId)) {
        reordered.add(tabMap[tabId]!);
        added.add(tabId);
      }
    }

    // Add any remaining tabs that weren't in the new order
    for (final tab in workspace.tabs) {
      if (!added.contains(tab.tabId)) {
        reordered.add(tab);
      }
    }

    return workspace.copyWith(tabs: reordered);
  }

  /// ============================================================
  /// OPEN RECENT
  /// ============================================================
  ///
  /// Reopens the most recently closed tab.
  /// Returns the updated workspace.
  /// ============================================================
  Workspace openRecent(Workspace workspace) {
    if (workspace.recentTabIds.isEmpty) return workspace;

    final recentTabId = workspace.recentTabIds.first;
    final updatedRecent = workspace.recentTabIds.skip(1).toList();

    // Note: The actual WorkspaceTab data needs to be stored for full restoration.
    // For now, we remove from recent list and signal that the tab needs recreation.
    // The provider layer should handle tab recreation from history.
    return workspace.copyWith(
      recentTabIds: updatedRecent,
    );
  }

  // ============================================================
  // WORKSPACE LIFECYCLE
  // ============================================================

  /// ============================================================
  /// SWITCH WORKSPACE
  /// ============================================================
  ///
  /// Switches to a different workspace, saving the current one first.
  /// ============================================================
  Future<Workspace> switchWorkspace(
    Workspace currentWorkspace,
    String newWorkspaceId,
  ) async {
    // Save current workspace
    await saveWorkspace(currentWorkspace);

    // Load the new workspace
    final snapshot = await _storage.loadWorkspace(newWorkspaceId);

    if (snapshot != null) {
      return Workspace.fromSnapshot(snapshot);
    }

    // Create a new empty workspace
    return Workspace(
      workspaceId: newWorkspaceId,
      displayName: 'Workspace $newWorkspaceId',
    );
  }

  /// ============================================================
  /// SAVE WORKSPACE
  /// ============================================================
  ///
  /// Persists the current workspace as a snapshot.
  /// ============================================================
  Future<void> saveWorkspace(Workspace workspace) async {
    final snapshot = workspace.captureSnapshot();
    await _storage.saveWorkspace(snapshot);

    // Also save organization-scoped workspace if applicable
    if (workspace.organizationId != null &&
        workspace.organizationId!.isNotEmpty) {
      await _storage.saveOrganizationWorkspace(
        workspace.organizationId!,
        snapshot,
      );
    }
  }

  /// ============================================================
  /// RESTORE WORKSPACE
  /// ============================================================
  ///
  /// Restores a workspace from a snapshot.
  /// Returns the restored workspace, or the current workspace
  /// if the snapshot ID doesn't match.
  /// ============================================================
  Future<Workspace> restoreWorkspace(
    Workspace currentWorkspace,
    String workspaceId,
  ) async {
    final snapshot = await _storage.loadWorkspace(workspaceId);

    if (snapshot != null) {
      return Workspace.fromSnapshot(snapshot);
    }

    return currentWorkspace;
  }

  /// ============================================================
  /// CLEAR WORKSPACE
  /// ============================================================
  ///
  /// Clears all non-pinned tabs from the workspace.
  /// Pinned tabs and their history survive.
  /// Returns the updated workspace with only pinned tabs.
  /// ============================================================
  Workspace clearWorkspace(Workspace workspace) {
    final pinnedTabs = workspace.tabs
        .where((t) => t.isPinned || workspace.pinnedTabIds.contains(t.tabId))
        .toList();

    return workspace.copyWith(
      tabs: pinnedTabs,
      activeTabId: pinnedTabs.isNotEmpty ? pinnedTabs.last.tabId : null,
      recentTabIds: [],
      navigationHistory: [],
    );
  }

  // ============================================================
  // NAVIGATION HISTORY
  // ============================================================

  /// ============================================================
  /// NAVIGATE BACK
  /// ============================================================
  ///
  /// Navigate backward in history.
  /// Pops from the back stack and pushes the current route to
  /// the forward stack.
  /// Returns the updated workspace with the previous route.
  /// ============================================================
  Workspace navigateBack(Workspace workspace) {
    if (!workspace.history.canGoBack) return workspace;

    final backStack = List<String>.from(workspace.history.backStack);
    final forwardStack = List<String>.from(workspace.history.forwardStack);

    final previousRoute = backStack.removeAt(0);

    // Push current route to forward stack if we have an active tab
    if (workspace.activeTab != null) {
      forwardStack.insert(0, workspace.activeTab!.route);
    }

    return workspace.copyWith(
      history: workspace.history.copyWith(
        backStack: backStack,
        forwardStack: forwardStack,
      ),
    );
  }

  /// ============================================================
  /// NAVIGATE FORWARD
  /// ============================================================
  ///
  /// Navigate forward in history.
  /// Pops from the forward stack and pushes the current route
  /// to the back stack.
  /// Returns the updated workspace with the next route.
  /// ============================================================
  Workspace navigateForward(Workspace workspace) {
    if (!workspace.history.canGoForward) return workspace;

    final backStack = List<String>.from(workspace.history.backStack);
    final forwardStack = List<String>.from(workspace.history.forwardStack);

    final nextRoute = forwardStack.removeAt(0);

    // Push current route to back stack
    if (workspace.activeTab != null) {
      backStack.insert(0, workspace.activeTab!.route);
    }

    return workspace.copyWith(
      history: workspace.history.copyWith(
        backStack: backStack,
        forwardStack: forwardStack,
      ),
    );
  }

  // ============================================================
  // SIDEBAR STATE
  // ============================================================

  /// ============================================================
  /// TOGGLE SIDEBAR
  /// ============================================================
  Workspace toggleSidebar(Workspace workspace) {
    return workspace.copyWith(
      sidebar: workspace.sidebar.copyWith(
        isExpanded: !workspace.sidebar.isExpanded,
      ),
    );
  }

  /// ============================================================
  /// SET SIDEBAR EXPANDED
  /// ============================================================
  Workspace setSidebarExpanded(Workspace workspace, bool expanded) {
    return workspace.copyWith(
      sidebar: workspace.sidebar.copyWith(isExpanded: expanded),
    );
  }

  /// ============================================================
  /// SET SIDEBAR VISIBLE
  /// ============================================================
  Workspace setSidebarVisible(Workspace workspace, bool visible) {
    return workspace.copyWith(
      sidebar: workspace.sidebar.copyWith(isVisible: visible),
    );
  }

  /// ============================================================
  /// SET FOCUSED MODULE
  /// ============================================================
  Workspace setFocusedModule(Workspace workspace, String? moduleKey) {
    return workspace.copyWith(
      sidebar: workspace.sidebar.copyWith(focusedModule: moduleKey),
    );
  }

  // ============================================================
  // SHELL / LAYOUT MODE
  // ============================================================

  /// ============================================================
  /// SET SHELL MODE
  /// ============================================================
  Workspace setShellMode(Workspace workspace, ShellLayoutMode mode) {
    return workspace.copyWith(shellMode: mode);
  }

  /// ============================================================
  /// SET SECONDARY PANEL
  /// ============================================================
  Workspace setSecondaryPanel(
    Workspace workspace, {
    required bool visible,
    double? width,
  }) {
    return workspace.copyWith(
      layout: workspace.layout.copyWith(
        secondaryPanelVisible: visible,
        secondaryPanelWidth: width ?? workspace.layout.secondaryPanelWidth,
      ),
    );
  }

  // ============================================================
  // HISTORY RECORDING
  // ============================================================

  /// ============================================================
  /// RECORD COMMAND
  /// ============================================================
  ///
  /// Records a command in the command palette history.
  /// Keeps the most recent commands (max 20).
  /// ============================================================
  Workspace recordCommand(Workspace workspace, String commandActionKey) {
    final updated = [
      commandActionKey,
      ...workspace.commandPaletteHistory
          .where((k) => k != commandActionKey),
    ].take(20).toList();

    return workspace.copyWith(commandPaletteHistory: updated);
  }

  /// ============================================================
  /// RECORD QUICK ACTION
  /// ============================================================
  ///
  /// Records a quick action in history.
  /// Keeps the most recent actions (max 20).
  /// ============================================================
  Workspace recordQuickAction(Workspace workspace, String actionKey) {
    final updated = [
      actionKey,
      ...workspace.quickActionsHistory.where((k) => k != actionKey),
    ].take(20).toList();

    return workspace.copyWith(quickActionsHistory: updated);
  }

  // ============================================================
  // MISCELLANEOUS
  // ============================================================

  /// ============================================================
  /// SET LAST DASHBOARD
  /// ============================================================
  Workspace setLastDashboard(Workspace workspace, String? route) {
    return workspace.copyWith(lastDashboard: route);
  }

  /// ============================================================
  /// SET WINDOW MODE
  /// ============================================================
  Workspace setWindowMode(Workspace workspace, WindowMode mode) {
    return workspace.copyWith(windowMode: mode);
  }

  /// ============================================================
  /// SET WORKSPACE ORGANIZATION
  /// ============================================================
  ///
  /// Associates this workspace with an organization.
  /// Used when switching organizations to restore the org's workspace.
  /// ============================================================
  Workspace setOrganization(
    Workspace workspace, {
    required String? organizationId,
  }) {
    return workspace.copyWith(organizationId: organizationId);
  }

  /// ============================================================
  /// LOAD ORGANIZATION WORKSPACE
  /// ============================================================
  ///
  /// Attempts to load the last workspace for a given organization.
  /// Returns null if no saved workspace exists.
  /// ============================================================
  Future<Workspace?> loadOrganizationWorkspace(
    String organizationId,
  ) async {
    final snapshot =
        await _storage.loadOrganizationWorkspace(organizationId);
    if (snapshot != null) {
      return Workspace.fromSnapshot(snapshot);
    }
    return null;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Generate a unique tab ID
  String _generateTabId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'tab-$timestamp-$random';
  }

  /// Push a route to navigation history (maintains max size)
  List<String> _pushToHistory(List<String> history, String route) {
    final updated = [
      route,
      ...history.where((r) => r != route),
    ];
    return updated.take(50).toList();
  }
}
