/// ============================================================
/// EXTENSION SLOT — Renders registered extensions for a slot
/// ============================================================
///
/// 🎯 PURPOSE:
///   Renders all extensions for a given shell region slot.
///   The shell never knows what the widgets are — it just renders them.
///
/// ✅ Runtime-Driven (single source of truth):
///   - Watches shellExtensionsBySlotProvider (Riverpod)
///   - Extensions come from the platform module runtime
///   - Disabled modules → extensions disappear automatically
///   - Maintenance mode → extensions auto-hidden
///   - Module install/removal → reactive via Riverpod refresh
///
/// ✅ Domain-Agnostic:
///   - Shell does not import feature modules
///   - Modules register extensions via descriptors
///   - Shell renders whatever is contributed
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/shell_extension.dart';
import '../../application/providers/shell_extension_provider.dart';

/// ============================================================
/// EXTENSION SLOT — Renders extensions for a given region slot
/// ============================================================
///
/// Usage:
/// ```dart
/// ExtensionSlot(
///   slot: ShellExtensionSlot.topBarActions,
///   separator: SizedBox(width: 4),
/// )
/// ```
/// ============================================================
class ExtensionSlot extends ConsumerWidget {
  /// Which slot to render extensions for
  final ShellExtensionSlot slot;

  /// Optional separator widget between extensions
  final Widget? separator;

  /// Optional wrapper for the entire slot
  final Widget Function(List<Widget> children)? wrapper;

  const ExtensionSlot({
    super.key,
    required this.slot,
    this.separator,
    this.wrapper,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Single source of truth: runtime-driven provider from module composition
    final runtimeExtensions = ref.watch(shellExtensionsBySlotProvider(slot));

    if (runtimeExtensions.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (int i = 0; i < runtimeExtensions.length; i++) {
      if (i > 0 && separator != null) {
        children.add(separator!);
      }
      children.add(runtimeExtensions[i].builder(context));
    }

    if (wrapper != null) {
      return wrapper!(children);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

