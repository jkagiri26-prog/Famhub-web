/// ============================================================
/// EXTENSION SLOT — Renders registered extensions for a slot
/// ============================================================
///
/// 🎯 PURPOSE:
///   Renders all extensions for a given shell region slot.
///   The shell never knows what the widgets are — it just renders them.
///
/// ✅ Runtime-Driven (replaces static registry):
///   - Watches shellExtensionsBySlotProvider (Riverpod)
///   - Extensions come from the platform module runtime
///   - Disabled modules → extensions disappear automatically
///   - Maintenance mode → extensions auto-hidden
///   - Module install/removal → reactive via Riverpod refresh
///
/// ✅ Backward Compatible:
///   - Falls back to legacy ShellExtensionRegistry.forSlot()
///     for modules not yet migrated to runtime descriptors
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
    // Primary source: runtime-driven provider from module composition
    final runtimeExtensions = ref.watch(shellExtensionsBySlotProvider(slot));

    // Secondary source: legacy static registry (backward compat)
    final legacyExtensions = ShellExtensionRegistry.forSlot(slot);

    // Merge: runtime takes priority, legacy is fallback
    final allExtensions = _mergeExtensions(runtimeExtensions, legacyExtensions);

    if (allExtensions.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (int i = 0; i < allExtensions.length; i++) {
      if (i > 0 && separator != null) {
        children.add(separator!);
      }
      children.add(allExtensions[i].builder(context));
    }

    if (wrapper != null) {
      return wrapper!(children);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// Merge runtime and legacy extensions.
  /// Runtime extensions take priority; legacy extensions fill gaps.
  List<ShellExtension> _mergeExtensions(
    List<ShellExtension> runtime,
    List<ShellExtension> legacy,
  ) {
    if (runtime.isEmpty) return legacy;
    if (legacy.isEmpty) return runtime;

    // Deduplicate by id (runtime wins)
    final runtimeIds = runtime.map((e) => e.id).toSet();
    final uniqueLegacy = legacy.where((e) => !runtimeIds.contains(e.id)).toList();

    return [...runtime, ...uniqueLegacy]
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }
}
