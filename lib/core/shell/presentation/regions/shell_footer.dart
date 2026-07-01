/// ============================================================
/// SHELL FOOTER — Domain-agnostic footer region
/// ============================================================
///
/// An optional footer region for the shell, displayed at the bottom
/// of desktop and ultra-wide layouts. Contains links, version info,
/// and legal text.
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../config/shell_config.dart';
import '../../../theme/shell_theme.dart';

/// ============================================================
/// SHELL FOOTER
/// ============================================================
class ShellFooter extends StatelessWidget {
  final FooterConfig config;

  const ShellFooter({super.key, this.config = const FooterConfig()});

  @override
  Widget build(BuildContext context) {
    if (!config.visible) return const SizedBox.shrink();

    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;

    return Container(
      height: config.height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          // ── Left: Links ──
          ...config.links.map((link) => _buildLink(link, palette)),
          if (config.links.isNotEmpty) const SizedBox(width: 16),

          const Spacer(),

          // ── Right: Version / Legal ──
          if (config.showVersion && config.versionText != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                config.versionText!,
                style: TextStyle(
                  fontSize: 11,
                  color: palette.tertiaryText,
                ),
              ),
            ),
          if (config.legalText != null)
            Text(
              config.legalText!,
              style: TextStyle(
                fontSize: 11,
                color: palette.tertiaryText,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLink(ShellFooterLink link, ShellColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: link.onTap,
        child: Text(
          link.label,
          style: TextStyle(
            fontSize: 11,
            color: palette.secondaryText,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
