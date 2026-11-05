/// ============================================================
/// WORKSPACE SECTION NAV — secondary vertical section navigation
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/layouts/ = reusable layout primitives
///
/// ✅ Responsibilities:
///   - Render a workspace's existing sections vertically on desktop
///   - Drive the page's existing [TabController] via animateTo
///   - Reflect the controller's selected index (no second state source)
///
/// ❌ Does NOT:
///   - Own tab state or create a new selection provider
///   - Own routes, history, or browser navigation
///   - Know about any specific workspace/module
///
/// The page owns the [TabController]; this widget is presentation only.
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../core/theme/shell_theme.dart';

/// ============================================================
/// WORKSPACE SECTION NAV ITEM
/// ============================================================
///
/// Metadata for one section. [index] is intentionally implicit: the
/// position in the list matches the existing TabController index.
class WorkspaceSectionNavItem {
  final String label;
  final IconData icon;
  final bool enabled;

  const WorkspaceSectionNavItem({
    required this.label,
    required this.icon,
    this.enabled = true,
  });
}

/// ============================================================
/// WORKSPACE SECTION NAV
/// ============================================================
///
/// Fixed-width vertical navigation for desktop/ultraWide workspace
/// pages. Must be placed in a bounded-height parent (e.g. a Row inside
/// an Expanded) so the internal ListView can scroll.
/// ============================================================
class WorkspaceSectionNav extends StatelessWidget {
  /// The page's existing TabController — the single source of truth.
  final TabController controller;

  /// Sections in TabController index order.
  final List<WorkspaceSectionNavItem> sections;

  /// Fixed width of the section rail.
  final double width;

  /// Optional callback invoked after [TabController.animateTo], mirroring
  /// the page's existing `TabBar.onTap` semantics (e.g. re-tap to reset
  /// an already-active section). Receives the selected index.
  final ValueChanged<int>? onSectionTap;

  const WorkspaceSectionNav({
    super.key,
    required this.controller,
    required this.sections,
    this.width = 220,
    this.onSectionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<ShellThemeColors>()?.palette;

    final backgroundColor = palette?.navigationBg ?? theme.colorScheme.surface;
    final selectedBackground =
        palette?.navigationSelectedBg ??
        theme.colorScheme.primary.withValues(alpha: 0.12);
    final selectedForeground =
        palette?.navigationSelectedText ?? theme.colorScheme.primary;
    final foreground = palette?.primaryText ?? theme.colorScheme.onSurface;
    final disabledForeground =
        palette?.tertiaryText ??
        theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return SizedBox(
      width: width,
      child: Container(
        color: backgroundColor,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                final selected = controller.index == index;
                final color = !section.enabled
                    ? disabledForeground
                    : selected
                    ? selectedForeground
                    : foreground;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: selected ? selectedBackground : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: section.enabled
                          ? () {
                              controller.animateTo(index);
                              onSectionTap?.call(index);
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Icon(section.icon, size: 18, color: color),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                section.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
