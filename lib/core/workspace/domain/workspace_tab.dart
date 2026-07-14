/// ============================================================
/// WORKSPACE TAB — PURE DATA MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/domain/ = workspace domain models
///
/// Represents a single tab within a workspace.
/// A tab corresponds to an open module or view.
///
/// ✅ Design Principles:
///   - Pure data — no evaluation logic
///   - Immutable — always use copyWith
///   - No Flutter dependencies
///   - Serializable for future persistence
/// ============================================================
library;

/// ============================================================
/// WORKSPACE TAB
/// ============================================================
///
/// Each tab represents an open module/view in the workspace.
/// Tabs can be pinned (always visible), focused (active), or recent.
/// ============================================================
class WorkspaceTab {
  /// Unique identifier for this tab instance
  final String tabId;

  /// The module key this tab belongs to (e.g., 'dashboard', 'inventory')
  final String moduleKey;

  /// Human-readable label for the tab
  final String label;

  /// Optional icon key for UI resolution
  final String? iconKey;

  /// The route path this tab navigates to
  final String route;

  /// Optional sub-route or state within the module
  final String? subRoute;

  /// Whether this tab is pinned (survives workspace clearing)
  final bool isPinned;

  /// Whether this tab is closable
  final bool isClosable;

  /// Timestamp when the tab was last accessed (milliseconds since epoch)
  final int lastAccessedAt;

  /// Optional metadata for restoring tab state
  final Map<String, dynamic>? metadata;

  const WorkspaceTab({
    required this.tabId,
    required this.moduleKey,
    required this.label,
    this.iconKey,
    required this.route,
    this.subRoute,
    this.isPinned = false,
    this.isClosable = true,
    this.lastAccessedAt = 0,
    this.metadata,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  WorkspaceTab copyWith({
    String? tabId,
    String? moduleKey,
    String? label,
    String? iconKey,
    String? route,
    String? subRoute,
    bool? isPinned,
    bool? isClosable,
    int? lastAccessedAt,
    Map<String, dynamic>? metadata,
  }) {
    return WorkspaceTab(
      tabId: tabId ?? this.tabId,
      moduleKey: moduleKey ?? this.moduleKey,
      label: label ?? this.label,
      iconKey: iconKey ?? this.iconKey,
      route: route ?? this.route,
      subRoute: subRoute ?? this.subRoute,
      isPinned: isPinned ?? this.isPinned,
      isClosable: isClosable ?? this.isClosable,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Touch the tab (update last accessed timestamp)
  WorkspaceTab touch() {
    return copyWith(
      lastAccessedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceTab && tabId == other.tabId;

  @override
  int get hashCode => tabId.hashCode;

  @override
  String toString() => 'WorkspaceTab($label [$moduleKey] — $route)';

  /// Serialize to a map for persistence
  Map<String, dynamic> toJson() => {
        'tabId': tabId,
        'moduleKey': moduleKey,
        'label': label,
        'iconKey': iconKey,
        'route': route,
        'subRoute': subRoute,
        'isPinned': isPinned,
        'isClosable': isClosable,
        'lastAccessedAt': lastAccessedAt,
        'metadata': metadata,
      };

  /// Deserialize from a map
  factory WorkspaceTab.fromJson(Map<String, dynamic> json) => WorkspaceTab(
        tabId: json['tabId'] as String,
        moduleKey: json['moduleKey'] as String,
        label: json['label'] as String,
        iconKey: json['iconKey'] as String?,
        route: json['route'] as String,
        subRoute: json['subRoute'] as String?,
        isPinned: json['isPinned'] as bool? ?? false,
        isClosable: json['isClosable'] as bool? ?? true,
        lastAccessedAt: json['lastAccessedAt'] as int? ?? 0,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}
