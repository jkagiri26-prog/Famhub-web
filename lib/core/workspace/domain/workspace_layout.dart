/// ============================================================
/// WORKSPACE LAYOUT — PURE DATA MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/domain/ = workspace domain models
///
/// Represents the visual layout configuration of a workspace.
/// Controls how the workspace surface is split and organized.
///
/// ✅ Design Principles:
///   - Pure data — no evaluation logic
///   - Immutable — always use copyWith
///   - No Flutter dependencies
///   - Serializable for future persistence
/// ============================================================
library;

/// ============================================================
/// SPLIT PANE
/// ============================================================
///
/// Represents a single pane in a split workspace layout.
/// Each pane can hold a tab or be further subdivided.
/// ============================================================
class SplitPane {
  /// Unique identifier for this pane
  final String paneId;

  /// The tab ID currently focused in this pane
  final String? focusedTabId;

  /// List of tab IDs open in this pane
  final List<String> tabIds;

  /// Split direction (null = no split)
  final SplitDirection? splitDirection;

  /// Child panes (when split)
  final List<SplitPane>? children;

  /// Ratio of this pane's size (0.0 - 1.0)
  final double ratio;

  const SplitPane({
    required this.paneId,
    this.focusedTabId,
    this.tabIds = const [],
    this.splitDirection,
    this.children,
    this.ratio = 0.5,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  SplitPane copyWith({
    String? paneId,
    String? focusedTabId,
    List<String>? tabIds,
    SplitDirection? splitDirection,
    List<SplitPane>? children,
    double? ratio,
  }) {
    return SplitPane(
      paneId: paneId ?? this.paneId,
      focusedTabId: focusedTabId ?? this.focusedTabId,
      tabIds: tabIds ?? this.tabIds,
      splitDirection: splitDirection ?? this.splitDirection,
      children: children ?? this.children,
      ratio: ratio ?? this.ratio,
    );
  }

  /// Whether this pane has a split
  bool get isSplit => splitDirection != null && children != null;

  /// Whether this pane is empty
  bool get isEmpty => tabIds.isEmpty;

  /// Serialize to map
  Map<String, dynamic> toJson() => {
        'paneId': paneId,
        'focusedTabId': focusedTabId,
        'tabIds': tabIds,
        'splitDirection': splitDirection?.name,
        'children': children?.map((c) => c.toJson()).toList(),
        'ratio': ratio,
      };

  /// Deserialize from map
  factory SplitPane.fromJson(Map<String, dynamic> json) => SplitPane(
        paneId: json['paneId'] as String,
        focusedTabId: json['focusedTabId'] as String?,
        tabIds: (json['tabIds'] as List<dynamic>?)?.cast<String>() ?? [],
        splitDirection: json['splitDirection'] != null
            ? SplitDirection.values.firstWhere(
                (e) => e.name == json['splitDirection'],
                orElse: () => SplitDirection.horizontal,
              )
            : null,
        children: (json['children'] as List<dynamic>?)
            ?.map((c) => SplitPane.fromJson(c as Map<String, dynamic>))
            .toList(),
        ratio: (json['ratio'] as num?)?.toDouble() ?? 0.5,
      );
}

/// ============================================================
/// SPLIT DIRECTION
/// ============================================================
enum SplitDirection {
  /// Split left/right
  horizontal,

  /// Split top/bottom
  vertical,
}

/// ============================================================
/// WORKSPACE LAYOUT
/// ============================================================
///
/// Complete layout configuration for a workspace.
/// Manages split panes, focused pane, and secondary panel state.
/// ============================================================
class WorkspaceLayout {
  /// The root pane (can be split)
  final SplitPane rootPane;

  /// The ID of the pane that currently has focus
  final String focusedPaneId;

  /// Whether the secondary panel is visible
  final bool secondaryPanelVisible;

  /// Width of the secondary panel (when visible)
  final double secondaryPanelWidth;

  /// Current shell mode
  final ShellLayoutMode shellMode;

  const WorkspaceLayout({
    this.rootPane = const SplitPane(paneId: 'main'),
    this.focusedPaneId = 'main',
    this.secondaryPanelVisible = false,
    this.secondaryPanelWidth = 320.0,
    this.shellMode = ShellLayoutMode.standard,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  WorkspaceLayout copyWith({
    SplitPane? rootPane,
    String? focusedPaneId,
    bool? secondaryPanelVisible,
    double? secondaryPanelWidth,
    ShellLayoutMode? shellMode,
  }) {
    return WorkspaceLayout(
      rootPane: rootPane ?? this.rootPane,
      focusedPaneId: focusedPaneId ?? this.focusedPaneId,
      secondaryPanelVisible:
          secondaryPanelVisible ?? this.secondaryPanelVisible,
      secondaryPanelWidth: secondaryPanelWidth ?? this.secondaryPanelWidth,
      shellMode: shellMode ?? this.shellMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceLayout &&
          rootPane == other.rootPane &&
          focusedPaneId == other.focusedPaneId &&
          secondaryPanelVisible == other.secondaryPanelVisible &&
          secondaryPanelWidth == other.secondaryPanelWidth &&
          shellMode == other.shellMode;

  @override
  int get hashCode => Object.hash(
        rootPane,
        focusedPaneId,
        secondaryPanelVisible,
        secondaryPanelWidth,
        shellMode,
      );

  /// Serialize to map
  Map<String, dynamic> toJson() => {
        'rootPane': rootPane.toJson(),
        'focusedPaneId': focusedPaneId,
        'secondaryPanelVisible': secondaryPanelVisible,
        'secondaryPanelWidth': secondaryPanelWidth,
        'shellMode': shellMode.name,
      };

  /// Deserialize from map
  factory WorkspaceLayout.fromJson(Map<String, dynamic> json) =>
      WorkspaceLayout(
        rootPane: SplitPane.fromJson(
            json['rootPane'] as Map<String, dynamic>? ?? {}),
        focusedPaneId: json['focusedPaneId'] as String? ?? 'main',
        secondaryPanelVisible:
            json['secondaryPanelVisible'] as bool? ?? false,
        secondaryPanelWidth:
            (json['secondaryPanelWidth'] as num?)?.toDouble() ?? 320.0,
        shellMode: ShellLayoutMode.values.firstWhere(
          (e) => e.name == json['shellMode'],
          orElse: () => ShellLayoutMode.standard,
        ),
      );
}

/// ============================================================
/// SHELL LAYOUT MODE
/// ============================================================
///
/// Mirrors the shell's visual modes for workspace awareness.
/// ============================================================
enum ShellLayoutMode {
  /// All regions visible
  standard,

  /// Content-focused, minimal chrome
  focus,

  /// Full-screen content, no chrome
  immersive,

  /// Dual-panel workspace layout
  splitWorkspace,

  /// Distraction-free for presentation
  presentation,

  /// Compact top bar only
  minimal,
}
