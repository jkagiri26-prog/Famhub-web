/// ============================================================
/// SHELL CONFIGURATION — Domain-agnostic shell configuration model
/// ============================================================
///
/// 🎯 PURPOSE:
///   Build the shell around configurable regions instead of hardcoded
///   widgets. This model defines which regions are visible and their
///   configuration. Modules contribute configuration, navigation items,
///   actions, and content — the shell just renders them.
///
/// ✅ Domain-Agnostic:
///   - No agriculture-specific assumptions
///   - Configurable regions: top bar, navigation, content, overlays,
///     status bar, floating actions, footer, secondary panel
///   - Same shell works for any application simply by changing config
///
/// ✅ Regions:
///   - TopBar:       App bar, context selector, global actions
///   - Navigation:   Sidebar (desktop), rail (tablet), bottom nav (mobile)
///   - Content:      Main content area (renders child)
///   - Overlay:      Command palette, notifications panel, search
///   - Floating:     FABs and overlay actions
///   - Status:       Connection, sync, background task indicators
///   - Footer:       Optional desktop footer with links
///   - Secondary:    Right-side panel (ultra-wide only)
///
/// 🏢 Usage for any domain:
///   ```dart
///   ShellConfig(
///     topBar: TopBarConfig(showProfile: true),
///     navigation: NavigationConfig(collapsible: true),
///     statusBar: StatusBarConfig(visible: true),
///     footer: FooterConfig(visible: true, showVersion: true),
///   );
///   ```
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../domain/contracts/shell_extension.dart';

/// ============================================================
/// SHELL CONFIGURATION
/// ============================================================
///
/// Complete configuration for all shell regions.
/// Each region is independent and can be toggled on/off.
/// ============================================================
class ShellConfig {
  /// Top bar configuration (app bar area)
  final TopBarConfig topBar;

  /// Navigation configuration (sidebar / rail / bottom nav)
  final NavigationConfig navigation;

  /// Status bar configuration (bottom status bar)
  final StatusBarConfig statusBar;

  /// Floating action configuration
  final FloatingActionConfig floatingActions;

  /// Overlay configuration (command palette, notifications, etc.)
  final OverlayConfig overlays;

  /// Content area configuration
  final ContentConfig content;

  /// Footer configuration (desktop/ultra-wide only)
  final FooterConfig footer;

  /// Secondary panel configuration (ultra-wide only)
  final SecondaryPanelConfig secondaryPanel;

  /// Current shell display mode — affects region visibility and behavior
  ///
  /// Modes can be switched at runtime by modules or user preference:
  /// - [ShellMode.standard]:      All regions visible
  /// - [ShellMode.focus]:         Hides navigation/status, full content
  /// - [ShellMode.immersive]:     Full-screen content, no chrome
  /// - [ShellMode.splitWorkspace]:Dual-panel workspace layout
  /// - [ShellMode.presentation]:  Distraction-free for sharing
  /// - [ShellMode.minimal]:       Compact top bar + content only
  final ShellMode mode;

  /// Whether keyboard navigation is enabled
  final bool enableKeyboardNavigation;

  /// Whether to show maintenance banner
  final bool showMaintenanceBanner;

  const ShellConfig({
    this.topBar = const TopBarConfig(),
    this.navigation = const NavigationConfig(),
    this.statusBar = const StatusBarConfig(),
    this.floatingActions = const FloatingActionConfig(),
    this.overlays = const OverlayConfig(),
    this.content = const ContentConfig(),
    this.footer = const FooterConfig(),
    this.secondaryPanel = const SecondaryPanelConfig(),
    this.mode = ShellMode.standard,
    this.enableKeyboardNavigation = true,
    this.showMaintenanceBanner = true,
  });

  ShellConfig copyWith({
    TopBarConfig? topBar,
    NavigationConfig? navigation,
    StatusBarConfig? statusBar,
    FloatingActionConfig? floatingActions,
    OverlayConfig? overlays,
    ContentConfig? content,
    FooterConfig? footer,
    SecondaryPanelConfig? secondaryPanel,
    ShellMode? mode,
    bool? enableKeyboardNavigation,
    bool? showMaintenanceBanner,
  }) {
    return ShellConfig(
      topBar: topBar ?? this.topBar,
      navigation: navigation ?? this.navigation,
      statusBar: statusBar ?? this.statusBar,
      floatingActions: floatingActions ?? this.floatingActions,
      overlays: overlays ?? this.overlays,
      content: content ?? this.content,
      footer: footer ?? this.footer,
      secondaryPanel: secondaryPanel ?? this.secondaryPanel,
      mode: mode ?? this.mode,
      enableKeyboardNavigation:
          enableKeyboardNavigation ?? this.enableKeyboardNavigation,
      showMaintenanceBanner:
          showMaintenanceBanner ?? this.showMaintenanceBanner,
    );
  }
}

// =================================================================
// TOP BAR
// =================================================================

/// ============================================================
/// TOP BAR CONFIGURATION
/// ============================================================
class TopBarConfig {
  /// Whether the top bar is visible
  final bool visible;

  /// Height of the top bar
  final double height;

  /// Whether to show the context selector
  final bool showContextSelector;

  /// Whether to show the module status indicator
  final bool showModuleStatus;

  /// Whether to show the search button
  final bool showSearch;

  /// Whether to show the notifications button
  final bool showNotifications;

  /// Whether to show the AI assistant button
  final bool showAiAssistant;

  /// Whether to show the settings button
  final bool showSettings;

  /// Whether to show the profile menu
  final bool showProfile;

  /// Custom actions to add to the top bar (right side)
  final List<ShellAction> customActions;

  const TopBarConfig({
    this.visible = true,
    this.height = 56.0,
    this.showContextSelector = true,
    this.showModuleStatus = true,
    this.showSearch = true,
    this.showNotifications = true,
    this.showAiAssistant = true,
    this.showSettings = true,
    this.showProfile = true,
    this.customActions = const [],
  });

  TopBarConfig copyWith({
    bool? visible,
    double? height,
    bool? showContextSelector,
    bool? showModuleStatus,
    bool? showSearch,
    bool? showNotifications,
    bool? showAiAssistant,
    bool? showSettings,
    bool? showProfile,
    List<ShellAction>? customActions,
  }) {
    return TopBarConfig(
      visible: visible ?? this.visible,
      height: height ?? this.height,
      showContextSelector: showContextSelector ?? this.showContextSelector,
      showModuleStatus: showModuleStatus ?? this.showModuleStatus,
      showSearch: showSearch ?? this.showSearch,
      showNotifications: showNotifications ?? this.showNotifications,
      showAiAssistant: showAiAssistant ?? this.showAiAssistant,
      showSettings: showSettings ?? this.showSettings,
      showProfile: showProfile ?? this.showProfile,
      customActions: customActions ?? this.customActions,
    );
  }
}

// =================================================================
// NAVIGATION
// =================================================================

/// ============================================================
/// NAVIGATION CONFIGURATION
/// ============================================================
class NavigationConfig {
  /// Whether navigation is visible at all
  final bool visible;

  /// Whether the sidebar is collapsible (desktop only)
  final bool collapsible;

  /// Navigation mode per device type
  final NavigationMode mobileMode;
  final NavigationMode tabletMode;
  final NavigationMode desktopMode;

  /// Whether to show section labels
  final bool showSectionLabels;

  /// Whether to show pinned section
  final bool showPinnedSection;

  const NavigationConfig({
    this.visible = true,
    this.collapsible = true,
    this.mobileMode = NavigationMode.bottomNav,
    this.tabletMode = NavigationMode.rail,
    this.desktopMode = NavigationMode.sidebar,
    this.showSectionLabels = true,
    this.showPinnedSection = true,
  });

  NavigationConfig copyWith({
    bool? visible,
    bool? collapsible,
    NavigationMode? mobileMode,
    NavigationMode? tabletMode,
    NavigationMode? desktopMode,
    bool? showSectionLabels,
    bool? showPinnedSection,
  }) {
    return NavigationConfig(
      visible: visible ?? this.visible,
      collapsible: collapsible ?? this.collapsible,
      mobileMode: mobileMode ?? this.mobileMode,
      tabletMode: tabletMode ?? this.tabletMode,
      desktopMode: desktopMode ?? this.desktopMode,
      showSectionLabels: showSectionLabels ?? this.showSectionLabels,
      showPinnedSection: showPinnedSection ?? this.showPinnedSection,
    );
  }
}

/// ============================================================
/// NAVIGATION MODE
/// ============================================================
enum NavigationMode {
  /// Full sidebar with labels
  sidebar,

  /// Compact icon rail
  rail,

  /// Bottom navigation bar
  bottomNav,

  /// No navigation (use other mechanisms)
  none,
}

// =================================================================
// STATUS BAR
// =================================================================

/// ============================================================
/// STATUS BAR CONFIGURATION
/// ============================================================
class StatusBarConfig {
  /// Whether the status bar is visible
  final bool visible;

  /// Height of the status bar
  final double height;

  /// Whether to show connection status
  final bool showConnectionStatus;

  /// Whether to show sync status
  final bool showSyncStatus;

  /// Custom status items (left side)
  final List<ShellStatusItem> leftItems;

  /// Custom status items (right side)
  final List<ShellStatusItem> rightItems;

  const StatusBarConfig({
    this.visible = false,
    this.height = 32.0,
    this.showConnectionStatus = true,
    this.showSyncStatus = true,
    this.leftItems = const [],
    this.rightItems = const [],
  });

  StatusBarConfig copyWith({
    bool? visible,
    double? height,
    bool? showConnectionStatus,
    bool? showSyncStatus,
    List<ShellStatusItem>? leftItems,
    List<ShellStatusItem>? rightItems,
  }) {
    return StatusBarConfig(
      visible: visible ?? this.visible,
      height: height ?? this.height,
      showConnectionStatus: showConnectionStatus ?? this.showConnectionStatus,
      showSyncStatus: showSyncStatus ?? this.showSyncStatus,
      leftItems: leftItems ?? this.leftItems,
      rightItems: rightItems ?? this.rightItems,
    );
  }
}

// =================================================================
// FOOTER
// =================================================================

/// ============================================================
/// FOOTER CONFIGURATION
/// ============================================================
class FooterConfig {
  /// Whether the footer is visible
  final bool visible;

  /// Height of the footer
  final double height;

  /// Whether to show version information
  final bool showVersion;

  /// Version text (e.g., 'v2.0.1')
  final String? versionText;

  /// Legal text (e.g., '© 2024 Company')
  final String? legalText;

  /// Footer links
  final List<ShellFooterLink> links;

  const FooterConfig({
    this.visible = false,
    this.height = 32.0,
    this.showVersion = true,
    this.versionText,
    this.legalText,
    this.links = const [],
  });

  FooterConfig copyWith({
    bool? visible,
    double? height,
    bool? showVersion,
    String? versionText,
    String? legalText,
    List<ShellFooterLink>? links,
  }) {
    return FooterConfig(
      visible: visible ?? this.visible,
      height: height ?? this.height,
      showVersion: showVersion ?? this.showVersion,
      versionText: versionText ?? this.versionText,
      legalText: legalText ?? this.legalText,
      links: links ?? this.links,
    );
  }
}

/// ============================================================
/// FOOTER LINK
/// ============================================================
class ShellFooterLink {
  final String label;
  final VoidCallback? onTap;

  const ShellFooterLink({
    required this.label,
    this.onTap,
  });
}

// =================================================================
// SECONDARY PANEL
// =================================================================

/// ============================================================
/// SECONDARY PANEL CONFIGURATION
/// ============================================================
class SecondaryPanelConfig {
  /// Whether the secondary panel is visible
  final bool visible;

  /// Width of the panel
  final double width;

  /// Panel title
  final String? title;

  /// Panel icon
  final IconData? icon;

  /// Empty state text
  final String? emptyText;

  /// Close callback
  final VoidCallback? onClose;

  const SecondaryPanelConfig({
    this.visible = false,
    this.width = 320.0,
    this.title,
    this.icon,
    this.emptyText,
    this.onClose,
  });

  SecondaryPanelConfig copyWith({
    bool? visible,
    double? width,
    String? title,
    IconData? icon,
    String? emptyText,
    VoidCallback? onClose,
  }) {
    return SecondaryPanelConfig(
      visible: visible ?? this.visible,
      width: width ?? this.width,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      emptyText: emptyText ?? this.emptyText,
      onClose: onClose ?? this.onClose,
    );
  }
}

// =================================================================
// FLOATING ACTIONS
// =================================================================

/// ============================================================
/// FLOATING ACTION CONFIGURATION
/// ============================================================
class FloatingActionConfig {
  /// Whether floating actions are enabled
  final bool enabled;

  /// Position of the FAB
  final FloatingActionPosition position;

  /// List of floating actions
  final List<ShellFloatingAction> actions;

  const FloatingActionConfig({
    this.enabled = false,
    this.position = FloatingActionPosition.bottomRight,
    this.actions = const [],
  });

  FloatingActionConfig copyWith({
    bool? enabled,
    FloatingActionPosition? position,
    List<ShellFloatingAction>? actions,
  }) {
    return FloatingActionConfig(
      enabled: enabled ?? this.enabled,
      position: position ?? this.position,
      actions: actions ?? this.actions,
    );
  }
}

/// FAB position
enum FloatingActionPosition {
  bottomRight,
  bottomLeft,
  topRight,
  topLeft,
}

// =================================================================
// OVERLAYS
// =================================================================

/// ============================================================
/// OVERLAY CONFIGURATION
/// ============================================================
class OverlayConfig {
  /// Whether the command palette is enabled
  final bool enableCommandPalette;

  /// Whether global search is enabled
  final bool enableGlobalSearch;

  /// Whether the notifications panel is enabled
  final bool enableNotificationsPanel;

  const OverlayConfig({
    this.enableCommandPalette = true,
    this.enableGlobalSearch = true,
    this.enableNotificationsPanel = true,
  });
}

// =================================================================
// CONTENT
// =================================================================

/// ============================================================
/// CONTENT CONFIGURATION
/// ============================================================
class ContentConfig {
  /// Maximum width of the content area (null = full width)
  final double? maxContentWidth;

  /// Whether to add horizontal padding to content
  final bool addContentPadding;

  /// Horizontal padding for content area
  final double contentPadding;

  const ContentConfig({
    this.maxContentWidth,
    this.addContentPadding = true,
    this.contentPadding = 16.0,
  });
}

// =================================================================
// SHELL MODE
// =================================================================

/// ============================================================
/// SHELL MODE — Controls shell layout and region visibility
/// ============================================================
///
/// Modes determine which regions are visible and how the shell
/// behaves. Can be switched at runtime by modules or user preference.
///
/// | Mode             | TopBar | Nav | Status | Footer | FABs | Use Case         |
/// |------------------|--------|-----|--------|--------|------|------------------|
/// | standard         |  ✅   | ✅  |  ✅   |  ✅   | ✅  | Normal operation |
/// | focus            |  ✅   | ❌  |  ❌   |  ❌   | ✅  | Deep work        |
/// | immersive        |  ❌   | ❌  |  ❌   |  ❌   | ❌  | Full-screen flow |
/// | splitWorkspace   |  ✅   | ✅  |  ✅   |  ✅   | ✅  | Multi-panel      |
/// | presentation     |  ✅   | ❌  |  ❌   |  ❌   | ❌  | Screen sharing   |
/// | minimal          |  ✅   | ❌  |  ❌   |  ❌   | ❌  | Compact UX       |
/// ============================================================
enum ShellMode {
  /// All regions visible. Default mode for normal app usage.
  standard,

  /// Hides navigation, status bar, and footer.
  /// Content takes full remaining space. Ideal for deep work.
  focus,

  /// Hides ALL chrome (top bar, nav, status, footer).
  /// Content fills the entire screen. For full-screen editors,
  /// media viewers, or distraction-free writing.
  immersive,

  /// Enables dual-workspace panel mode (content split).
  /// Navigation, status, and footer remain visible.
  splitWorkspace,

  /// Distraction-free mode for presentations and screen sharing.
  /// Top bar visible but simplified; all other chrome hidden.
  presentation,

  /// Minimal shell: compact top bar only, no navigation/status/footer.
  /// For embedded or widget-style experiences.
  minimal,
}

// =================================================================
// SHARED MODELS
// =================================================================

/// ============================================================
/// SHELL ACTION — Reusable action model
/// ============================================================
class ShellAction {
  final String id;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool showBadge;
  final String? badgeText;

  const ShellAction({
    required this.id,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.showBadge = false,
    this.badgeText,
  });
}

/// ============================================================
/// SHELL STATUS ITEM — Status bar item model
/// ============================================================
class ShellStatusItem {
  final String id;
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const ShellStatusItem({
    required this.id,
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });
}

/// ============================================================
/// SHELL FLOATING ACTION — FAB model
/// ============================================================
class ShellFloatingAction {
  final String id;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ShellFloatingAction({
    required this.id,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });
}
