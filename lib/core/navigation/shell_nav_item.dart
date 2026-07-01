/// ============================================================
/// SHELL NAV ITEM — Domain-agnostic navigation item widget
/// ============================================================
///
/// 🎯 PURPOSE:
///   Replace all hardcoded agriculture-specific navigation with
///   a configurable navigation item that consumes ShellTheme.
///
/// ✅ Domain-Agnostic:
///   - No agriculture-specific icons or colors
///   - All colors come from ShellTheme/ShellColorPalette
///   - Consistent hover/focus/selected states
///   - Supports badges, maintenance mode, pinned state
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../theme/shell_theme.dart';

/// ============================================================
/// NAV ITEM INTERACTION STATE
/// ============================================================
enum ShellNavInteraction {
  idle,
  hovered,
  selected,
  focused,
  disabled,
  maintenance,
}

/// ============================================================
/// SHELL NAV ITEM CONTAINER
/// ============================================================
///
/// A reusable container for navigation items with consistent
/// hover, focus, and selection behavior.
/// ============================================================
class ShellNavItemContainer extends StatefulWidget {
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

  const ShellNavItemContainer({
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
  State<ShellNavItemContainer> createState() => _ShellNavItemContainerState();
}

class _ShellNavItemContainerState extends State<ShellNavItemContainer> {
  bool _isHovered = false;
  bool _isFocused = false;

  ShellColorPalette get _palette =>
      Theme.of(context).extension<ShellThemeColors>()?.palette ??
      ShellTheme.defaultLight;

  bool get _isInteractive =>
      !widget.isDisabled && !widget.isMaintenance && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors();

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
          cursor:
              _isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: _isInteractive
                ? () {
                    widget.onTap?.call();
                    setState(() => _isHovered = false);
                  }
                : null,
            onDoubleTap: _isInteractive ? widget.onDoubleTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: colors.backgroundColor,
                borderRadius: widget.borderRadius,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  _NavItemColors _resolveColors() {
    final p = _palette;

    if (widget.isDisabled) {
      return _NavItemColors(
        backgroundColor: Colors.transparent,
        foregroundColor: p.tertiaryText,
        iconColor: p.tertiaryText,
        indicatorColor: Colors.transparent,
      );
    }

    if (widget.isMaintenance) {
      return _NavItemColors(
        backgroundColor: Colors.transparent,
        foregroundColor: p.tertiaryText,
        iconColor: p.tertiaryText,
        indicatorColor: Colors.transparent,
      );
    }

    if (widget.isSelected) {
      return _NavItemColors(
        backgroundColor: p.navigationSelectedBg,
        foregroundColor: p.navigationSelectedText,
        iconColor: p.navigationSelectedText,
        indicatorColor: p.navigationSelectedText,
      );
    }

    if (_isFocused) {
      return _NavItemColors(
        backgroundColor: p.navigationSelectedBg.withValues(alpha: 0.5),
        foregroundColor: p.navigationSelectedText,
        iconColor: p.navigationSelectedText,
        indicatorColor: p.navigationSelectedText,
      );
    }

    if (_isHovered) {
      return _NavItemColors(
        backgroundColor: p.navigationHover,
        foregroundColor: p.primaryText,
        iconColor: p.secondaryText,
        indicatorColor: Colors.transparent,
      );
    }

    return _NavItemColors(
      backgroundColor: Colors.transparent,
      foregroundColor: p.primaryText,
      iconColor: p.secondaryText,
      indicatorColor: Colors.transparent,
    );
  }
}

class _NavItemColors {
  final Color backgroundColor;
  final Color foregroundColor;
  final Color iconColor;
  final Color indicatorColor;

  const _NavItemColors({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconColor,
    required this.indicatorColor,
  });
}

/// ============================================================
/// SHELL NAV ITEM INDICATOR
/// ============================================================
class ShellNavIndicator extends StatelessWidget {
  final bool isSelected;

  const ShellNavIndicator({super.key, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 4,
      height: 20,
      decoration: BoxDecoration(
        color: isSelected ? palette.navigationSelectedText : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// ============================================================
/// SHELL NAV BADGE
/// ============================================================
class ShellNavBadge extends StatelessWidget {
  final String? text;
  final int? count;
  final Color? color;
  final bool mini;

  const ShellNavBadge({
    super.key,
    this.text,
    this.count,
    this.color,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = text ?? (count?.toString());
    if (displayText == null) return const SizedBox.shrink();

    final bgColor = color ?? Theme.of(context).colorScheme.error;

    if (mini) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          displayText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
