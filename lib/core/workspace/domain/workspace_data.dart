/// ============================================================
/// WORKSPACE — CORE DOMAIN MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/domain/ = workspace domain models
///
/// A Workspace represents the user's current working session.
/// It owns all runtime state: open tabs, pinned tabs, recent tabs,
/// split panes, focused pane, secondary panel, command palette
/// history, quick actions history, navigation history, last dashboard,
/// window mode, sidebar state, and workspace layout.
///
/// ✅ Responsibilities:
///   - Hold all workspace runtime state
///   - Be immutable — create new instances on state change
///   - Expose computed queries: hasTabs, isEmpty, activeTab
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain UI logic
///   - Manage persistence directly
///
/// ✅ Design Principles:
///   - Pure data — no evaluation logic
///   - Immutable — always use copyWith
///   - No Flutter dependencies
///   - Serializable for future persistence
/// ============================================================
library;

import 'workspace_tab.dart';
import 'workspace_layout.dart';
import 'workspace_snapshot.dart';

/// ============================================================
/// WORKSPACE
/// ============================================================
///
/// The runtime workspace model. This is the single source of
/// truth for the user's active working session.
///
/// A workspace is identified by its workspaceId and optionally
/// associated with an organization ID (for org-scoped workspaces).
/// ============================================================
class Workspace {
  /// Unique identifier for this workspace
  final String workspaceId;

  /// Display name for the workspace
  final String displayName;

  /// Organization this workspace belongs to (empty = personal)
  final String? organizationId;

  /// All open tabs
  final List<WorkspaceTab> tabs;

  /// The ID of the currently active/focused tab
  final String? activeTabId;

  /// Pinned tab IDs (tabs that survive workspace clearing)
  final List<String> pinnedTabIds;

  /// Recently closed tab IDs (for undo close)
  final List<String> recentTabIds;

  /// Workspace layout (split panes, focused pane, secondary panel)
  final WorkspaceLayout layout;

  /// Sidebar state
  final SidebarState sidebar;

  /// Navigation history
  final NavigationHistory history;

  /// Command palette history (recent command action keys)
  final List<String> commandPaletteHistory;

  /// Quick actions history (recent action keys)
  final List<String> quickActionsHistory;

  /// Navigation history entries (routes visited)
  final List<String> navigationHistory;

  /// The last visited dashboard route
  final String? lastDashboard;

  /// Window mode
  final WindowMode windowMode;

  /// Current shell/layout mode
  final ShellLayoutMode shellMode;

  const Workspace({
    required this.workspaceId,
    this.displayName = 'Default Workspace',
    this.organizationId,
    this.tabs = const [],
    this.activeTabId,
    this.pinnedTabIds = const [],
    this.recentTabIds = const [],
    this.layout = const WorkspaceLayout(),
    this.sidebar = const SidebarState(),
    this.history = const NavigationHistory(),
    this.commandPaletteHistory = const [],
    this.quickActionsHistory = const [],
    this.navigationHistory = const [],
    this.lastDashboard,
    this.windowMode = WindowMode.normal,
    this.shellMode = ShellLayoutMode.standard,
  });

  // ── Computed Properties ──

  /// Whether the workspace has any open tabs
  bool get hasTabs => tabs.isNotEmpty;

  /// Whether the workspace is empty (no tabs, no state)
  bool get isEmpty =>
      tabs.isEmpty && pinnedTabIds.isEmpty && recentTabIds.isEmpty;

  /// Get the active tab object
  WorkspaceTab? get activeTab {
    if (activeTabId == null) return null;
    try {
      return tabs.firstWhere((t) => t.tabId == activeTabId);
    } catch (_) {
      return null;
    }
  }

  /// Get pinned tabs
  List<WorkspaceTab> get pinnedTabs =>
      tabs.where((t) => t.isPinned || pinnedTabIds.contains(t.tabId)).toList();

  /// Get unpinned (regular) tabs
  List<WorkspaceTab> get regularTabs =>
      tabs.where((t) => !(t.isPinned || pinnedTabIds.contains(t.tabId))).toList();

  /// Get the active tab's module key
  String? get activeModuleKey => activeTab?.moduleKey;

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  Workspace copyWith({
    String? workspaceId,
    String? displayName,
    String? organizationId,
    List<WorkspaceTab>? tabs,
    String? activeTabId,
    List<String>? pinnedTabIds,
    List<String>? recentTabIds,
    WorkspaceLayout? layout,
    SidebarState? sidebar,
    NavigationHistory? history,
    List<String>? commandPaletteHistory,
    List<String>? quickActionsHistory,
    List<String>? navigationHistory,
    String? lastDashboard,
    WindowMode? windowMode,
    ShellLayoutMode? shellMode,
  }) {
    return Workspace(
      workspaceId: workspaceId ?? this.workspaceId,
      displayName: displayName ?? this.displayName,
      organizationId: organizationId ?? this.organizationId,
      tabs: tabs ?? this.tabs,
      activeTabId: activeTabId ?? this.activeTabId,
      pinnedTabIds: pinnedTabIds ?? this.pinnedTabIds,
      recentTabIds: recentTabIds ?? this.recentTabIds,
      layout: layout ?? this.layout,
      sidebar: sidebar ?? this.sidebar,
      history: history ?? this.history,
      commandPaletteHistory:
          commandPaletteHistory ?? this.commandPaletteHistory,
      quickActionsHistory: quickActionsHistory ?? this.quickActionsHistory,
      navigationHistory: navigationHistory ?? this.navigationHistory,
      lastDashboard: lastDashboard ?? this.lastDashboard,
      windowMode: windowMode ?? this.windowMode,
      shellMode: shellMode ?? this.shellMode,
    );
  }

  /// ============================================================
  /// SNAPSHOT
  /// ============================================================
  ///
  /// Create a point-in-time snapshot of this workspace.
  /// The snapshot is fully serializable for persistence.
  /// ============================================================
  WorkspaceSnapshot captureSnapshot() => WorkspaceSnapshot(
        workspaceId: workspaceId,
        organizationId: organizationId,
        tabs: List.from(tabs),
        activeTabId: activeTabId,
        pinnedTabIds: List.from(pinnedTabIds),
        recentTabIds: List.from(recentTabIds),
        sidebar: sidebar,
        shellMode: shellMode,
        history: history,
        layout: layout,
        commandPaletteHistory: List.from(commandPaletteHistory),
        quickActionsHistory: List.from(quickActionsHistory),
        navigationHistory: List.from(navigationHistory),
        lastDashboard: lastDashboard,
        windowMode: windowMode,
        capturedAt: DateTime.now().millisecondsSinceEpoch,
      );

  /// ============================================================
  /// RESTORE FROM SNAPSHOT
  /// ============================================================
  ///
  /// Create a workspace from a snapshot.
  /// ============================================================
  factory Workspace.fromSnapshot(WorkspaceSnapshot snapshot) => Workspace(
        workspaceId: snapshot.workspaceId,
        organizationId: snapshot.organizationId,
        tabs: List.from(snapshot.tabs),
        activeTabId: snapshot.activeTabId,
        pinnedTabIds: List.from(snapshot.pinnedTabIds),
        recentTabIds: List.from(snapshot.recentTabIds),
        layout: snapshot.layout,
        sidebar: snapshot.sidebar,
        history: snapshot.history,
        commandPaletteHistory: List.from(snapshot.commandPaletteHistory),
        quickActionsHistory: List.from(snapshot.quickActionsHistory),
        navigationHistory: List.from(snapshot.navigationHistory),
        lastDashboard: snapshot.lastDashboard,
        windowMode: snapshot.windowMode,
        shellMode: snapshot.shellMode,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workspace && workspaceId == other.workspaceId;

  @override
  int get hashCode => workspaceId.hashCode;

  @override
  String toString() =>
      'Workspace($displayName [$workspaceId] — ${tabs.length} tabs)';
}
