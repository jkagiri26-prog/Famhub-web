/// ============================================================
/// REUSABLE NAVIGATION ITEM STYLING (HOVER SYSTEM)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Define reusable navigation item interaction states
///   - hover, selected, focused, disabled, maintenance
///   - Each state has its own visual treatment
///   - No scattered hover logic
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Import feature modules
/// ============================================================
library;

import 'package:flutter/material.dart';

/// ============================================================
/// NAVIGATION ITEM STATE
/// ============================================================
///
/// Describes the complete visual state of a navigation item.
/// Each interaction state maps to specific visual properties.
/// ============================================================
enum NavItemInteraction {
  /// Default idle state
  idle,

  /// Hovered by mouse
  hovered,

  /// Currently selected/active
  selected,

  /// Focused via keyboard
  focused,

  /// Disabled and non-interactive
  disabled,

  /// Under maintenance
  maintenance,
}

/// ============================================================
/// NAVIGATION ITEM COLORS (DERIVED FROM THEME)
/// ============================================================
///
/// Defines the complete color palette for a navigation item
/// across all possible interaction states.
/// ============================================================
class NavItemColors {
  final Color backgroundColor;
  final Color foregroundColor;
  final Color iconColor;
  final Color indicatorColor;
  final Color badgeColor;

  const NavItemColors({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconColor,
    required this.indicatorColor,
    required this.badgeColor,
  });
}

/// ============================================================
/// NAVIGATION STYLE RESOLVER
/// ============================================================
///
/// Centralized style resolution for navigation items.
/// Maps interaction states to concrete visual properties.
///
/// Usage:
/// ```dart
/// final style = NavItemStyleResolver.resolve(
///   theme: Theme.of(context),
///   interaction: isSelected ? NavItemInteraction.selected : NavItemInteraction.idle,
///   isHovered: _isHovered,
/// );
/// ```
/// ============================================================
class NavItemStyleResolver {
  /// Resolve the complete visual style for a navigation item
  static NavItemColors resolve({
    required ThemeData theme,
    required NavItemInteraction interaction,
    bool isHovered = false,
    bool isFocused = false,
  }) {
    // Determine effective interaction state
    final effectiveState = _resolveEffectiveState(
      interaction: interaction,
      isHovered: isHovered,
      isFocused: isFocused,
    );

    switch (effectiveState) {
      case NavItemInteraction.idle:
        return NavItemColors(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          iconColor: Colors.grey.shade600,
          indicatorColor: Colors.transparent,
          badgeColor: Colors.red,
        );

      case NavItemInteraction.hovered:
        return NavItemColors(
          backgroundColor: Colors.grey.shade100,
          foregroundColor: Colors.black87,
          iconColor: Colors.grey.shade700,
          indicatorColor: Colors.transparent,
          badgeColor: Colors.red,
        );

      case NavItemInteraction.selected:
        return NavItemColors(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          foregroundColor: theme.colorScheme.primary,
          iconColor: theme.colorScheme.primary,
          indicatorColor: theme.colorScheme.primary,
          badgeColor: Colors.red,
        );

      case NavItemInteraction.focused:
        return NavItemColors(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.04),
          foregroundColor: theme.colorScheme.primary,
          iconColor: theme.colorScheme.primary,
          indicatorColor: theme.colorScheme.primary,
          badgeColor: Colors.red,
        );

      case NavItemInteraction.disabled:
        return NavItemColors(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.grey.shade400,
          iconColor: Colors.grey.shade400,
          indicatorColor: Colors.transparent,
          badgeColor: Colors.grey,
        );

      case NavItemInteraction.maintenance:
        return NavItemColors(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.grey.shade400,
          iconColor: Colors.grey.shade400,
          indicatorColor: Colors.transparent,
          badgeColor: Colors.orange,
        );
    }
  }

  /// Resolve the effective interaction state
  static NavItemInteraction _resolveEffectiveState({
    required NavItemInteraction interaction,
    bool isHovered = false,
    bool isFocused = false,
  }) {
    // State priority: disabled > maintenance > selected > focused > hovered
    if (interaction == NavItemInteraction.disabled) {
      return NavItemInteraction.disabled;
    }
    if (interaction == NavItemInteraction.maintenance) {
      return NavItemInteraction.maintenance;
    }
    if (interaction == NavItemInteraction.selected) {
      return NavItemInteraction.selected;
    }
    if (isFocused) {
      return NavItemInteraction.focused;
    }
    if (isHovered) {
      return NavItemInteraction.hovered;
    }
    return interaction;
  }
}

/// ============================================================
/// NAVIGATION ITEM CONTAINER (REUSABLE HOVER WRAPPER)
/// ============================================================
///
/// A reusable container widget that provides consistent
/// hover, focus, and interaction behavior for navigation items.
///
/// Usage:
/// ```dart
/// NavItemContainer(
///   isSelected: false,
///   isDisabled: false,
///   isMaintenance: false,
///   onTap: () => navigate(),
///   child: ...,
/// )
/// ```
/// ============================================================
class NavItemContainer extends StatefulWidget {
  final bool isSelected;
  final bool isDisabled;
  final bool isMaintenance;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadiusGeometry borderRadius;
  final double? width;
  final double? height;

  const NavItemContainer({
    super.key,
    this.isSelected = false,
    this.isDisabled = false,
    this.isMaintenance = false,
    this.onTap,
    this.onDoubleTap,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.width,
    this.height,
  });

  @override
  State<NavItemContainer> createState() => _NavItemContainerState();
}

class _NavItemContainerState extends State<NavItemContainer> {
  bool _isHovered = false;
  bool _isFocused = false;

  NavItemColors get _colors {
    final effective = _resolveEffectiveInteraction();
    return NavItemStyleResolver.resolve(
      theme: Theme.of(context),
      interaction: effective,
      isHovered: _isHovered,
      isFocused: _isFocused,
    );
  }

  NavItemInteraction _resolveEffectiveInteraction() {
    if (widget.isDisabled) return NavItemInteraction.disabled;
    if (widget.isMaintenance) return NavItemInteraction.maintenance;
    if (widget.isSelected) return NavItemInteraction.selected;
    return NavItemInteraction.idle;
  }

  bool get _isInteractive =>
      !widget.isDisabled && !widget.isMaintenance && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin,
      child: Focus(
        canRequestFocus: _isInteractive,
        onFocusChange: (focused) {
          setState(() => _isFocused = focused);
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: _isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: _isInteractive ? () {
              widget.onTap?.call();
              setState(() => _isHovered = false);
            } : null,
            onDoubleTap: _isInteractive ? widget.onDoubleTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: _colors.backgroundColor,
                borderRadius: widget.borderRadius,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// NAVIGATION ITEM INDICATOR
/// ============================================================
///
/// A small vertical bar indicating the selected item.
/// Rendered on the right side of selected items.
/// ============================================================
class NavItemIndicator extends StatelessWidget {
  final bool isSelected;
  final Color? color;

  const NavItemIndicator({
    super.key,
    this.isSelected = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 4,
      height: 20,
      decoration: BoxDecoration(
        color: isSelected
            ? (color ?? Theme.of(context).colorScheme.primary)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
