/// ============================================================
/// WORKSPACE SNAPSHOT — SERIALIZABLE STATE CAPTURE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/domain/ = workspace domain models
///
/// A snapshot is a point-in-time capture of the entire workspace
/// state. It is fully serializable for persistence, restoration,
/// and AI context.
///
/// ✅ Design Principles:
///   - Immutable — never modified after creation
///   - Fully serializable to JSON
///   - No Flutter dependencies
///   - Contains ALL workspace state in one object
///   - Ready for Supabase persistence
/// ============================================================
library;

import 'workspace_tab.dart';
import 'workspace_layout.dart';

/// ============================================================
/// SIDEBAR STATE
/// ============================================================
///
/// Represents the sidebar visibility and configuration state.
/// ============================================================
class SidebarState {
  /// Whether the sidebar is expanded
  final bool isExpanded;

  /// Whether the sidebar is visible at all
  final bool isVisible;

  /// The currently focused/highlighted module in the sidebar
  final String? focusedModule;

  const SidebarState({
    this.isExpanded = true,
    this.isVisible = true,
    this.focusedModule,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  SidebarState copyWith({
    bool? isExpanded,
    bool? isVisible,
    String? focusedModule,
  }) {
    return SidebarState(
      isExpanded: isExpanded ?? this.isExpanded,
      isVisible: isVisible ?? this.isVisible,
      focusedModule: focusedModule ?? this.focusedModule,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SidebarState &&
          isExpanded == other.isExpanded &&
          isVisible == other.isVisible &&
          focusedModule == other.focusedModule;

  @override
  int get hashCode => Object.hash(isExpanded, isVisible, focusedModule);

  /// Serialize to map
  Map<String, dynamic> toJson() => {
        'isExpanded': isExpanded,
        'isVisible': isVisible,
        'focusedModule': focusedModule,
      };

  /// Deserialize from map
  factory SidebarState.fromJson(Map<String, dynamic> json) => SidebarState(
        isExpanded: json['isExpanded'] as bool? ?? true,
        isVisible: json['isVisible'] as bool? ?? true,
        focusedModule: json['focusedModule'] as String?,
      );
}

/// ============================================================
/// NAVIGATION HISTORY
/// ============================================================
///
/// Tracks the user's navigation history within the workspace.
/// Supports back/forward navigation.
/// ============================================================
class NavigationHistory {
  /// Stack of previous locations (most recent first)
  final List<String> backStack;

  /// Stack of forward locations (most recent first)
  final List<String> forwardStack;

  /// Maximum size of the history stack
  final int maxSize;

  const NavigationHistory({
    this.backStack = const [],
    this.forwardStack = const [],
    this.maxSize = 50,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  NavigationHistory copyWith({
    List<String>? backStack,
    List<String>? forwardStack,
    int? maxSize,
  }) {
    return NavigationHistory(
      backStack: backStack ?? this.backStack,
      forwardStack: forwardStack ?? this.forwardStack,
      maxSize: maxSize ?? this.maxSize,
    );
  }

  /// Whether we can navigate back
  bool get canGoBack => backStack.isNotEmpty;

  /// Whether we can navigate forward
  bool get canGoForward => forwardStack.isNotEmpty;

  /// Serialize to map
  Map<String, dynamic> toJson() => {
        'backStack': backStack,
        'forwardStack': forwardStack,
        'maxSize': maxSize,
      };

  /// Deserialize from map
  factory NavigationHistory.fromJson(Map<String, dynamic> json) =>
      NavigationHistory(
        backStack:
            (json['backStack'] as List<dynamic>?)?.cast<String>() ?? [],
        forwardStack:
            (json['forwardStack'] as List<dynamic>?)?.cast<String>() ?? [],
        maxSize: json['maxSize'] as int? ?? 50,
      );
}

/// ============================================================
/// WORKSPACE SNAPSHOT
/// ============================================================
///
/// Complete point-in-time capture of the entire workspace state.
///
/// Contains:
///   - Workspace identity
///   - All open tabs
///   - Active/pinned/recent tabs
///   - Sidebar state
///   - Shell/Layout mode
///   - Navigation history
///   - Focused pane
///   - Secondary panel state
///   - Command palette & quick actions history
///   - Window mode
///   - Last dashboard
/// ============================================================
class WorkspaceSnapshot {
  /// Unique workspace identifier
  final String workspaceId;

  /// Organization this workspace belongs to (if any)
  final String? organizationId;

  /// All open tabs
  final List<WorkspaceTab> tabs;

  /// The ID of the currently active/focused tab
  final String? activeTabId;

  /// Pinned tab IDs (survive workspace clearing)
  final List<String> pinnedTabIds;

  /// Recently closed tab IDs (for undo)
  final List<String> recentTabIds;

  /// Sidebar state
  final SidebarState sidebar;

  /// Current shell/layout mode
  final ShellLayoutMode shellMode;

  /// Navigation history
  final NavigationHistory history;

  /// Workspace layout (split panes, focused pane, etc.)
  final WorkspaceLayout layout;

  /// Command palette history (list of recent command action keys)
  final List<String> commandPaletteHistory;

  /// Quick actions history (list of recent action keys)
  final List<String> quickActionsHistory;

  /// Navigation history entries (routes visited)
  final List<String> navigationHistory;

  /// The last visited dashboard route
  final String? lastDashboard;

  /// Window mode (normal, maximized, fullscreen)
  final WindowMode windowMode;

  /// Timestamp when this snapshot was created (milliseconds since epoch)
  final int capturedAt;

  // ── Spatial State ──

  /// The currently selected spatial asset ID (farm, field, block)
  final String? selectedSpatialAssetId;

  /// The currently selected boundary ID
  final String? boundaryId;

  /// The active capture session ID (if any)
  final String? captureSessionId;

  /// The last viewed field/asset ID
  final String? lastViewedFieldId;

  /// The last map zoom state
  final double? lastMapZoom;

  /// The last selected polygon/feature ID
  final String? lastSelectedPolygonId;

  const WorkspaceSnapshot({
    required this.workspaceId,
    this.organizationId,
    this.tabs = const [],
    this.activeTabId,
    this.pinnedTabIds = const [],
    this.recentTabIds = const [],
    this.sidebar = const SidebarState(),
    this.shellMode = ShellLayoutMode.standard,
    this.history = const NavigationHistory(),
    this.layout = const WorkspaceLayout(),
    this.commandPaletteHistory = const [],
    this.quickActionsHistory = const [],
    this.navigationHistory = const [],
    this.lastDashboard,
    this.windowMode = WindowMode.normal,
    this.capturedAt = 0,
    this.selectedSpatialAssetId,
    this.boundaryId,
    this.captureSessionId,
    this.lastViewedFieldId,
    this.lastMapZoom,
    this.lastSelectedPolygonId,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  WorkspaceSnapshot copyWith({
    String? workspaceId,
    String? organizationId,
    List<WorkspaceTab>? tabs,
    String? activeTabId,
    List<String>? pinnedTabIds,
    List<String>? recentTabIds,
    SidebarState? sidebar,
    ShellLayoutMode? shellMode,
    NavigationHistory? history,
    WorkspaceLayout? layout,
    List<String>? commandPaletteHistory,
    List<String>? quickActionsHistory,
    List<String>? navigationHistory,
    String? lastDashboard,
    WindowMode? windowMode,
    int? capturedAt,
    String? selectedSpatialAssetId,
    String? boundaryId,
    String? captureSessionId,
    String? lastViewedFieldId,
    double? lastMapZoom,
    String? lastSelectedPolygonId,
  }) {
    return WorkspaceSnapshot(
      workspaceId: workspaceId ?? this.workspaceId,
      organizationId: organizationId ?? this.organizationId,
      tabs: tabs ?? this.tabs,
      activeTabId: activeTabId ?? this.activeTabId,
      pinnedTabIds: pinnedTabIds ?? this.pinnedTabIds,
      recentTabIds: recentTabIds ?? this.recentTabIds,
      sidebar: sidebar ?? this.sidebar,
      shellMode: shellMode ?? this.shellMode,
      history: history ?? this.history,
      layout: layout ?? this.layout,
      commandPaletteHistory:
          commandPaletteHistory ?? this.commandPaletteHistory,
      quickActionsHistory: quickActionsHistory ?? this.quickActionsHistory,
      navigationHistory: navigationHistory ?? this.navigationHistory,
      lastDashboard: lastDashboard ?? this.lastDashboard,
      windowMode: windowMode ?? this.windowMode,
      capturedAt: capturedAt ?? this.capturedAt,
      selectedSpatialAssetId:
          selectedSpatialAssetId ?? this.selectedSpatialAssetId,
      boundaryId: boundaryId ?? this.boundaryId,
      captureSessionId: captureSessionId ?? this.captureSessionId,
      lastViewedFieldId: lastViewedFieldId ?? this.lastViewedFieldId,
      lastMapZoom: lastMapZoom ?? this.lastMapZoom,
      lastSelectedPolygonId:
          lastSelectedPolygonId ?? this.lastSelectedPolygonId,
    );
  }

  /// ============================================================
  /// SERIALIZATION
  /// ============================================================

  /// Serialize to map for JSON/backend persistence
  Map<String, dynamic> toJson() => {
        'workspaceId': workspaceId,
        'organizationId': organizationId,
        'tabs': tabs.map((t) => t.toJson()).toList(),
        'activeTabId': activeTabId,
        'pinnedTabIds': pinnedTabIds,
        'recentTabIds': recentTabIds,
        'sidebar': sidebar.toJson(),
        'shellMode': shellMode.name,
        'history': history.toJson(),
        'layout': layout.toJson(),
        'commandPaletteHistory': commandPaletteHistory,
        'quickActionsHistory': quickActionsHistory,
        'navigationHistory': navigationHistory,
        'lastDashboard': lastDashboard,
        'windowMode': windowMode.name,
        'capturedAt': capturedAt,
        'selectedSpatialAssetId': selectedSpatialAssetId,
        'boundaryId': boundaryId,
        'captureSessionId': captureSessionId,
        'lastViewedFieldId': lastViewedFieldId,
        'lastMapZoom': lastMapZoom,
        'lastSelectedPolygonId': lastSelectedPolygonId,
      };

  /// Deserialize from map
  factory WorkspaceSnapshot.fromJson(Map<String, dynamic> json) =>
      WorkspaceSnapshot(
        workspaceId: json['workspaceId'] as String,
        organizationId: json['organizationId'] as String?,
        tabs: (json['tabs'] as List<dynamic>?)
                ?.map((t) =>
                    WorkspaceTab.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        activeTabId: json['activeTabId'] as String?,
        pinnedTabIds:
            (json['pinnedTabIds'] as List<dynamic>?)?.cast<String>() ?? [],
        recentTabIds:
            (json['recentTabIds'] as List<dynamic>?)?.cast<String>() ?? [],
        sidebar: json['sidebar'] != null
            ? SidebarState.fromJson(
                json['sidebar'] as Map<String, dynamic>)
            : const SidebarState(),
        shellMode: ShellLayoutMode.values.firstWhere(
          (e) => e.name == json['shellMode'],
          orElse: () => ShellLayoutMode.standard,
        ),
        history: json['history'] != null
            ? NavigationHistory.fromJson(
                json['history'] as Map<String, dynamic>)
            : const NavigationHistory(),
        layout: json['layout'] != null
            ? WorkspaceLayout.fromJson(
                json['layout'] as Map<String, dynamic>)
            : const WorkspaceLayout(),
        commandPaletteHistory: (json['commandPaletteHistory']
                as List<dynamic>?)
            ?.cast<String>() ?? [],
        quickActionsHistory: (json['quickActionsHistory']
                as List<dynamic>?)
            ?.cast<String>() ?? [],
        navigationHistory:
            (json['navigationHistory'] as List<dynamic>?)?.cast<String>() ??
                [],
        lastDashboard: json['lastDashboard'] as String?,
        windowMode: WindowMode.values.firstWhere(
          (e) => e.name == json['windowMode'],
          orElse: () => WindowMode.normal,
        ),
        capturedAt: json['capturedAt'] as int? ?? 0,
        selectedSpatialAssetId:
            json['selectedSpatialAssetId'] as String?,
        boundaryId: json['boundaryId'] as String?,
        captureSessionId: json['captureSessionId'] as String?,
        lastViewedFieldId: json['lastViewedFieldId'] as String?,
        lastMapZoom: (json['lastMapZoom'] as num?)?.toDouble(),
        lastSelectedPolygonId:
            json['lastSelectedPolygonId'] as String?,
      );
}

/// ============================================================
/// WINDOW MODE
/// ============================================================
enum WindowMode {
  /// Normal window
  normal,

  /// Maximized window
  maximized,

  /// Full-screen mode
  fullscreen,

  /// Minimized to tray
  minimized,
}
