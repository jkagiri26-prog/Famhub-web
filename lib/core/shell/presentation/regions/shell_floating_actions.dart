/// ============================================================
/// SHELL FLOATING ACTIONS — Domain-agnostic FAB region
/// ============================================================
///
/// Configurable floating action buttons. Supports single FAB or
/// speed dial pattern. All colors from ShellTheme.
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../config/shell_config.dart';
import '../../../theme/shell_theme.dart';

/// ============================================================
/// SHELL FLOATING ACTIONS
/// ============================================================
class ShellFloatingActions extends StatelessWidget {
  final FloatingActionConfig config;

  const ShellFloatingActions({super.key, this.config = const FloatingActionConfig()});

  @override
  Widget build(BuildContext context) {
    if (!config.enabled || config.actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;

    // Single FAB
    if (config.actions.length == 1) {
      final action = config.actions.first;
      return FloatingActionButton(
        onPressed: action.onPressed,
        tooltip: action.tooltip,
        backgroundColor: action.backgroundColor ?? palette.primary,
        foregroundColor: action.foregroundColor ?? Colors.white,
        mini: false,
        child: Icon(action.icon),
      );
    }

    // Multiple FABs — return a Column of small FABs
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: config.actions.map((action) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FloatingActionButton.small(
            onPressed: action.onPressed,
            tooltip: action.tooltip,
            backgroundColor: action.backgroundColor ?? palette.primary,
            foregroundColor: action.foregroundColor ?? Colors.white,
            child: Icon(action.icon, size: 20),
          ),
        );
      }).toList(),
    );
  }
}
