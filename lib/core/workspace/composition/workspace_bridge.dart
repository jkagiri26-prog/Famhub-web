/// ============================================================
/// WORKSPACE BRIDGE — COMPOSITION INTEGRATION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/composition/ = composition integration
///
/// The Workspace Bridge provides a single access point for the
/// active workspace to all downstream consumers:
///   - Shell (tabs, sidebar, layout, secondary panel)
///   - AI Assistant (current module, open tabs, focused tab)
///   - Organization Runtime (org-scoped workspace)
///   - Navigation (active route, history)
///
/// No consumer should read workspace state independently.
/// All workspace data flows through this bridge.
///
/// ✅ Responsibilities:
///   - Provide the active workspace to all consumers
///   - Provide convenience methods for shell integration
///   - Feed AI context with current workspace state
///
/// ✅ Usage:
///   ```dart
///   final bridge = ref.watch(workspaceBridgeProvider);
///   final tabs = bridge.openTabs;
///   final activeModule = bridge.activeModuleKey;
///   ```
///
/// ❌ Does NOT:
///   - Contain UI
///   - Replace individual providers
///   - Evaluate decisions
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/workspace/domain/workspace_data.dart';
import 'package:famhub_app/core/workspace/domain/workspace_tab.dart';
import 'package:famhub_app/core/workspace/domain/workspace_layout.dart';
import 'package:famhub_app/core/workspace/domain/workspace_snapshot.dart';
import 'package:famhub_app/core/workspace/application/workspace_engine.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_provider.dart';

/// ============================================================
/// WORKSPACE BRIDGE
/// ============================================================
///
/// Provides a single access point for the active workspace
/// to all downstream consumers.
///
/// Integrates with:
///   - WorkspaceEngine (business logic)
///   - Workspace (state)
///   - ActiveWorkspaceProvider (Riverpod integration)
/// ============================================================
class WorkspaceBridge {
  final Workspace _workspace;
  final WorkspaceEngine _engine;

  const WorkspaceBridge({
    required Workspace workspace,
    required WorkspaceEngine engine,
  })  : _workspace = workspace,
        _engine = engine;

  // ============================================================
  // WORKSPACE IDENTITY
  // ============================================================

  /// The active workspace ID
  String get workspaceId => _workspace.workspaceId;

  /// The display name
  String get displayName => _workspace.displayName;

  /// The associated organization ID (if any)
  String? get organizationId => _workspace.organizationId;

  // ============================================================
  // TAB STATE
  // ============================================================

  /// All open tabs
  List<WorkspaceTab> get openTabs => _workspace.tabs;

  /// The currently active/focused tab
  WorkspaceTab? get activeTab => _workspace.activeTab;

  /// The active tab ID
  String? get activeTabId => _workspace.activeTabId;

  /// The active module key
  String? get activeModuleKey => _workspace.activeModuleKey;

  /// Pinned tabs
  List<WorkspaceTab> get pinnedTabs => _workspace.pinnedTabs;

  /// Regular (unpinned) tabs
  List<WorkspaceTab> get regularTabs => _workspace.regularTabs;

  /// Recently closed tab IDs
  List<String> get recentTabIds => _workspace.recentTabIds;

  /// Whether there are any open tabs
  bool get hasTabs => _workspace.hasTabs;

  /// Whether the workspace is empty
  bool get isEmpty => _workspace.isEmpty;

  // ============================================================
  // SIDEBAR STATE
  // ============================================================

  /// Sidebar expanded state
  bool get sidebarExpanded => _workspace.sidebar.isExpanded;

  /// Sidebar visible state
  bool get sidebarVisible => _workspace.sidebar.isVisible;

  /// The focused/highlighted module in the sidebar
  String? get focusedModule => _workspace.sidebar.focusedModule;

  /// Full sidebar state
  SidebarState get sidebarState => _workspace.sidebar;

  // ============================================================
  // LAYOUT STATE
  // ============================================================

  /// Current shell mode
  ShellLayoutMode get shellMode => _workspace.shellMode;

  /// Whether the secondary panel is visible
  bool get secondaryPanelVisible =>
      _workspace.layout.secondaryPanelVisible;

  /// Secondary panel width
  double get secondaryPanelWidth =>
      _workspace.layout.secondaryPanelWidth;

  /// Full layout
  WorkspaceLayout get layout => _workspace.layout;

  // ============================================================
  // HISTORY
  // ============================================================

  /// Navigation history
  NavigationHistory get history => _workspace.history;

  /// Whether we can go back
  bool get canGoBack => _workspace.history.canGoBack;

  /// Whether we can go forward
  bool get canGoForward => _workspace.history.canGoForward;

  /// Command palette history
  List<String> get commandPaletteHistory =>
      _workspace.commandPaletteHistory;

  /// Quick actions history
  List<String> get quickActionsHistory =>
      _workspace.quickActionsHistory;

  /// Navigation history (routes)
  List<String> get navigationHistory => _workspace.navigationHistory;

  /// Last dashboard route
  String? get lastDashboard => _workspace.lastDashboard;

  // ============================================================
  // WINDOW MODE
  // ============================================================

  /// Current window mode
  WindowMode get windowMode => _workspace.windowMode;

  // ============================================================
  // SNAPSHOT
  // ============================================================

  /// Capture a serializable snapshot of the workspace
  WorkspaceSnapshot get snapshot => _workspace.captureSnapshot();

  // ============================================================
  // ENGINE METHODS (for consumers that need the engine directly)
  // ============================================================

  /// Get the workspace engine (for tab/layout operations)
  WorkspaceEngine get engine => _engine;

  /// Get raw workspace (for passing to other engines)
  Workspace get workspace => _workspace;
}

/// ============================================================
/// PROVIDER: WORKSPACE BRIDGE
/// ============================================================
///
/// Provides the WorkspaceBridge for all consumers to use.
///
/// Every consumer (Shell, AI Assistant, Navigation)
/// should use this bridge to read workspace state.
///
/// ✅ Shell Integration:
///   The shell reads:
///   - bridge.sidebarState — Sidebar visibility/expanded
///   - bridge.focusedModule — Current module in sidebar
///   - bridge.openTabs — All open tabs
///   - bridge.secondaryPanelVisible — Secondary panel state
///   - bridge.layout — Workspace layout configuration
///
/// ✅ AI Context:
///   The AI Assistant reads:
///   - bridge.activeModuleKey — Current module
///   - bridge.activeTab — Focused tab
///   - bridge.workspaceId — Current workspace
///   - bridge.organizationId — Current organization
///
/// ✅ Usage:
///   ```dart
///   final bridge = ref.watch(workspaceBridgeProvider);
///
///   // Read tab state
///   final tabs = bridge.openTabs;
///   final active = bridge.activeTab;
///
///   // Read sidebar state
///   final sidebar = bridge.sidebarState;
///
///   // Read layout
///   final mode = bridge.shellMode;
///
///   // Access engine for operations
///   final updated = bridge.engine.openTab(bridge.workspace, newTab);
///   ```
/// ============================================================
final workspaceBridgeProvider = Provider<WorkspaceBridge>((ref) {
  final workspace = ref.watch(activeWorkspaceProvider);
  final engine = ref.watch(workspaceEngineProvider);
  return WorkspaceBridge(workspace: workspace, engine: engine);
});
