/// ============================================================
/// SHELL SECONDARY PANEL — Domain-agnostic right panel
/// ============================================================
///
/// A right-side panel for secondary content like activity feed,
/// notifications, or context-specific panels. Rendered only on
/// ultra-wide screens (1440px+).
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../config/shell_config.dart';
import '../../../theme/shell_theme.dart';

/// ============================================================
/// SHELL SECONDARY PANEL
/// ============================================================
class ShellSecondaryPanel extends StatelessWidget {
  final SecondaryPanelConfig config;
  final ShellColorPalette palette;

  const ShellSecondaryPanel({
    super.key,
    required this.config,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: config.width,
      color: palette.surface,
      child: Column(
        children: [
          // ── Panel Header ──
          if (config.title != null)
            _buildHeader(),

          // ── Panel Content ──
          Expanded(
            child: Center(
              child: Text(
                config.emptyText ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: palette.tertiaryText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          if (config.icon != null) ...[
            Icon(config.icon, size: 16, color: palette.secondaryText),
            const SizedBox(width: 8),
          ],
          Text(
            config.title!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.primaryText,
            ),
          ),
          const Spacer(),
          if (config.onClose != null)
            GestureDetector(
              onTap: config.onClose,
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: palette.tertiaryText,
              ),
            ),
        ],
      ),
    );
  }
}
