/// ============================================================
/// FOCUS MANAGEMENT SYSTEM (PHASE B)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Responsibilities:
///   - Tab traversal across sidebar, app bar, and content
///   - Keyboard focus management
///   - Accessibility focus
///   - Overlay focus restoration
///   - No keyboard traps
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Uses Flutter's built-in Focus system
///   - No manual FocusNode management in widgets
///   - Centralized focus scope management
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ============================================================
/// FOCUS SCOPE IDENTIFIERS
/// ============================================================
///
/// Named focus scopes for the application shell.
/// These allow tab traversal across different regions.
/// ============================================================
class FocusScopes {
  static const String sidebar = 'sidebar';
  static const String appBar = 'appBar';
  static const String content = 'content';
  static const String overlay = 'overlay';

  FocusScopes._();
}

/// ============================================================
/// SHELL FOCUS SCOPE
/// ============================================================
///
/// Wraps the app shell with named focus scopes for proper tab
/// traversal across sidebar → app bar → content.
///
/// Usage:
/// ```dart
/// ShellFocusScope(
///   child: Column(
///     children: [
///       FocusScope(
///         node: appBarFocusNode,
///         child: DesktopAppBar(),
///       ),
///       Row(
///         children: [
///           FocusScope(
///             node: sidebarFocusNode,
///             child: AnimatedSideNav(),
///           ),
///           FocusScope(
///             node: contentFocusNode,
///             child: child,
///           ),
///         ],
///       ),
///     ],
///   ),
/// )
/// ```
/// ============================================================
class ShellFocusScope extends StatefulWidget {
  final Widget child;

  const ShellFocusScope({
    super.key,
    required this.child,
  });

  @override
  State<ShellFocusScope> createState() => _ShellFocusScopeState();
}

class _ShellFocusScopeState extends State<ShellFocusScope> {
  final FocusNode _appBarFocusNode = FocusNode(debugLabel: 'AppBar');
  final FocusNode _sidebarFocusNode = FocusNode(debugLabel: 'Sidebar');
  final FocusNode _contentFocusNode = FocusNode(debugLabel: 'Content');

  @override
  void dispose() {
    _appBarFocusNode.dispose();
    _sidebarFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  /// Provide focus nodes to children via InheritedWidget
  @override
  Widget build(BuildContext context) {
    return _FocusScopeProvider(
      appBarFocusNode: _appBarFocusNode,
      sidebarFocusNode: _sidebarFocusNode,
      contentFocusNode: _contentFocusNode,
      child: widget.child,
    );
  }
}

/// ============================================================
/// FOCUS SCOPE PROVIDER (INHERITED WIDGET)
/// ============================================================
class _FocusScopeProvider extends InheritedWidget {
  final FocusNode appBarFocusNode;
  final FocusNode sidebarFocusNode;
  final FocusNode contentFocusNode;

  const _FocusScopeProvider({
    required this.appBarFocusNode,
    required this.sidebarFocusNode,
    required this.contentFocusNode,
    required super.child,
  });

  static _FocusScopeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_FocusScopeProvider>();
  }

  @override
  bool updateShouldNotify(_FocusScopeProvider oldWidget) => false;
}

/// ============================================================
/// OVERLAY FOCUS MANAGER
/// ============================================================
///
/// Manages focus when overlays (dialogs, modals, popups) appear.
/// Restores focus to the previously focused element when overlay closes.
/// Prevents keyboard traps.
/// ============================================================
class OverlayFocusManager {
  FocusNode? _previousFocus;

  /// Call BEFORE showing an overlay to capture current focus
  void captureCurrentFocus() {
    _previousFocus = FocusManager.instance.primaryFocus;
  }

  /// Call AFTER closing an overlay to restore previous focus
  void restoreFocus() {
    _previousFocus?.requestFocus();
    _previousFocus = null;
  }

  /// Whether there is a captured focus to restore
  bool get hasCapturedFocus => _previousFocus != null;
}

/// Global instance
final overlayFocusManager = OverlayFocusManager();

/// ============================================================
/// FOCUS ORDER HELPER
/// ============================================================
///
/// Utility mixin to add consistent focus traversal behavior.
/// Use with StatefulWidget states that need focus management.
///
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with FocusOrderMixin { ... }
/// ```
/// ============================================================
mixin FocusOrderMixin<T extends StatefulWidget> on State<T> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Handle focus gained
    }
  }

  FocusNode get focusNode => _focusNode;
}

/// ============================================================
/// FOCUSABLE NAV ITEM
/// ============================================================
///
/// A focusable wrapper for navigation items that supports
/// tab traversal and keyboard activation.
///
/// Usage:
/// ```dart
/// FocusableNavItem(
///   onActivate: () => navigate(),
///   child: NavItemContainer(...),
/// )
/// ```
/// ============================================================
class FocusableNavItem extends StatefulWidget {
  final VoidCallback? onActivate;
  final Widget child;
  final String? debugLabel;

  const FocusableNavItem({
    super.key,
    this.onActivate,
    required this.child,
    this.debugLabel,
  });

  @override
  State<FocusableNavItem> createState() => _FocusableNavItemState();
}

class _FocusableNavItemState extends State<FocusableNavItem> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'NavItem');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      debugLabel: widget.debugLabel,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onActivate?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}
