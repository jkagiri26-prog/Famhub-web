/// ============================================================
/// KEYBOARD NAVIGATION SYSTEM
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Responsibilities:
///   - Define keyboard shortcuts using Flutter's Shortcuts/Actions
///   - Ctrl+K → Command Palette
///   - Ctrl+B → Toggle Sidebar
///   - Ctrl+/ → Search
///   - Esc → Close Overlays
///   - No manual keyboard event interception
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Directly manipulate DOM
///   - Use raw keyboard listeners
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/shell/application/controllers/sidebar_controller.dart';
import 'package:famhub_app/core/shell/config/shell_config.dart';

// =================================================================
// ACTION CLASSES (Flutter Actions)
// =================================================================

/// Action: Toggle sidebar (Ctrl+B)
class ToggleSidebarAction extends Action<ToggleSidebarIntent> {
  final WidgetRef ref;

  ToggleSidebarAction(this.ref);

  @override
  void invoke(covariant ToggleSidebarIntent intent) {
    ref.read(sidebarControllerProvider.notifier).toggle();
  }
}

/// Action: Open command palette (Ctrl+K)
class OpenCommandPaletteAction extends Action<OpenCommandPaletteIntent> {
  final BuildContext context;
  final bool enabled;

  OpenCommandPaletteAction(this.context, {this.enabled = true});

  @override
  void invoke(covariant OpenCommandPaletteIntent intent) {
    if (!enabled) return;
    // Show command palette - use ScaffoldMessenger or dialog
    _showCommandPalette(context);
  }

  void _showCommandPalette(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CommandPaletteDialog(),
    );
  }
}

/// Action: Open search (Ctrl+/)
class OpenSearchAction extends Action<OpenSearchIntent> {
  final BuildContext context;

  OpenSearchAction(this.context);

  @override
  void invoke(covariant OpenSearchIntent intent) {
    // Navigate to search page
    context.go('/search');
  }
}

/// Action: Close overlays (Esc)
class CloseOverlaysAction extends Action<CloseOverlaysIntent> {
  final BuildContext context;

  CloseOverlaysAction(this.context);

  @override
  void invoke(covariant CloseOverlaysIntent intent) {
    // Pop any open dialogs or bottom sheets
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

// =================================================================
// INTENT CLASSES (Flutter Shortcuts/Intents)
// =================================================================

/// Intent for toggling sidebar
class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

/// Intent for opening command palette
class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

/// Intent for opening search
class OpenSearchIntent extends Intent {
  const OpenSearchIntent();
}

/// Intent for closing overlays
class CloseOverlaysIntent extends Intent {
  const CloseOverlaysIntent();
}

// =================================================================
// KEYBOARD SHORTCUTS WIDGET
// =================================================================

/// Wraps the app with keyboard shortcut handling.
/// Uses Flutter's Shortcuts/Actions/Focus system.
///
/// Place this at the root of your widget tree.
class KeyboardShortcutsHandler extends ConsumerStatefulWidget {
  final Widget child;
  final OverlayConfig overlays;

  const KeyboardShortcutsHandler({
    super.key,
    required this.child,
    this.overlays = const OverlayConfig(),
  });

  @override
  ConsumerState<KeyboardShortcutsHandler> createState() =>
      _KeyboardShortcutsHandlerState();
}

class _KeyboardShortcutsHandlerState
    extends ConsumerState<KeyboardShortcutsHandler> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Request focus so keyboard shortcuts work
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          // Ctrl+K → Command Palette
          SingleActivator(LogicalKeyboardKey.keyK, control: true):
              OpenCommandPaletteIntent(),
          // Ctrl+B → Toggle Sidebar
          SingleActivator(LogicalKeyboardKey.keyB, control: true):
              ToggleSidebarIntent(),
          // Ctrl+/ → Search
          SingleActivator(LogicalKeyboardKey.slash, control: true):
              OpenSearchIntent(),
          // Esc → Close Overlays
          SingleActivator(LogicalKeyboardKey.escape):
              CloseOverlaysIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ToggleSidebarIntent: ToggleSidebarAction(ref),
            OpenCommandPaletteIntent: OpenCommandPaletteAction(
              context,
              enabled: widget.overlays.enableCommandPalette,
            ),
            OpenSearchIntent: OpenSearchAction(context),
            CloseOverlaysIntent: CloseOverlaysAction(context),
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// ============================================================
/// COMMAND PALETTE DIALOG
/// ============================================================
///
/// Simple command palette that lists available keyboard shortcuts.
/// Future: can be extended to show module search.
/// ============================================================
class _CommandPaletteDialog extends ConsumerWidget {
  const _CommandPaletteDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Icon(
                  Icons.keyboard_rounded,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Command Palette',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // ── Shortcut list ──
            const _ShortcutRow(
              shortcut: 'Ctrl + K',
              description: 'Open Command Palette',
            ),
            const SizedBox(height: 8),
            const _ShortcutRow(
              shortcut: 'Ctrl + B',
              description: 'Toggle Sidebar',
            ),
            const SizedBox(height: 8),
            const _ShortcutRow(
              shortcut: 'Ctrl + /',
              description: 'Search',
            ),
            const SizedBox(height: 8),
            const _ShortcutRow(
              shortcut: 'Esc',
              description: 'Close Overlays / Dialogs',
            ),
            const SizedBox(height: 8),
            const _ShortcutRow(
              shortcut: 'Tab',
              description: 'Navigate between elements',
            ),

            const SizedBox(height: 16),
            // ── Footer ──
            Text(
              'Press Esc to close',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// SHORTCUT ROW
/// ============================================================
class _ShortcutRow extends StatelessWidget {
  final String shortcut;
  final String description;

  const _ShortcutRow({
    required this.shortcut,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            shortcut,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          description,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
