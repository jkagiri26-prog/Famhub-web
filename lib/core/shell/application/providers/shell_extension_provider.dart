/// ============================================================
/// SHELL EXTENSION PROVIDER — Runtime-driven extension bridge
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/application/providers/ = shell application layer
///
/// ✅ Responsibilities:
///   - Bridge the composition layer's ShellExtensionDescriptors
///     to shell-consumable ShellExtension objects
///   - Filter by slot for ExtensionSlot widget consumption
///   - Never import feature modules
///
/// 🎯 Why this exists (replacing static ShellExtensionRegistry):
///   The platform has a complete module runtime with:
///     - Module Registry
///     - Module Activation
///     - Feature Flags
///     - Maintenance Mode
///   A static registry cannot participate in these runtime capabilities.
///
///   This provider sits in the dependency flow:
///     Module → ModuleRuntime → RuntimeDescriptorEngine →
///     shellExtensionDescriptorsProvider → shellExtensionProvider → Shell
///
/// ✅ Runtime capabilities:
///   - Disabled modules → extensions automatically disappear
///   - Maintenance mode → extensions hidden
///   - Feature flags → evaluated at composition layer
///   - Module install/removal → reactive update via Riverpod
///
/// ✅ Rules:
///   - Never imports feature modules
///   - Never hardcodes extension IDs
///   - Shell remains a consumer only
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import '../../domain/contracts/shell_extension.dart';

/// ============================================================
/// PROVIDER: SHELL EXTENSIONS (RUNTIME-DRIVEN)
/// ============================================================
///
/// Converts ShellExtensionDescriptors from the composition engine
/// into ShellExtension objects consumable by the shell.
///
/// This replaces the static ShellExtensionRegistry.
///
/// Governance is applied by the composition layer:
///   - Only enabled modules contribute descriptors
///   - Maintenance mode modules are skipped
///   - The provider auto-updates when modules change
/// ============================================================
final shellExtensionProvider = Provider<List<ShellExtension>>((ref) {
  // Watch the composition layer's descriptors
  final descriptorsAsync = ref.watch(shellExtensionDescriptorsProvider);

  return descriptorsAsync.when(
    data: (descriptors) {
      return descriptors.map((desc) {
        // Convert descriptor to shell extension
        // The builder is a placeholder — the module's widget
        // resolver will provide the actual widget at render time.
        final ext = ShellExtension(
          id: desc.id,
          slot: _parseSlot(desc.slot),
          priority: desc.priority,
          builder: (_) => const SizedBox.shrink(),
        );
        ext.extensionKey = desc.featureFlagKey;
        return ext;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// ============================================================
/// PROVIDER: SHELL EXTENSIONS BY SLOT
/// ============================================================
///
/// Filters all shell extensions by a specific slot.
/// The ExtensionSlot widget watches this provider.
/// ============================================================
final shellExtensionsBySlotProvider =
    Provider.family<List<ShellExtension>, ShellExtensionSlot>(
        (ref, slot) {
  final all = ref.watch(shellExtensionProvider);
  return all.where((e) => e.slot == slot).toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));
});

/// ============================================================
/// Parse a slot string from descriptor to ShellExtensionSlot enum
/// ============================================================
ShellExtensionSlot _parseSlot(String slot) {
  switch (slot) {
    case 'topBarLeading':
      return ShellExtensionSlot.topBarLeading;
    case 'topBarActions':
      return ShellExtensionSlot.topBarActions;
    case 'topBarTrailing':
      return ShellExtensionSlot.topBarTrailing;
    case 'navigationTop':
      return ShellExtensionSlot.navigationTop;
    case 'navigationBottom':
      return ShellExtensionSlot.navigationBottom;
    case 'contentTop':
      return ShellExtensionSlot.contentTop;
    case 'contentBottom':
      return ShellExtensionSlot.contentBottom;
    case 'floatingArea':
      return ShellExtensionSlot.floatingArea;
    case 'overlayArea':
      return ShellExtensionSlot.overlayArea;
    case 'statusBarLeft':
      return ShellExtensionSlot.statusBarLeft;
    case 'statusBarRight':
      return ShellExtensionSlot.statusBarRight;
    case 'footerLeft':
      return ShellExtensionSlot.footerLeft;
    case 'footerRight':
      return ShellExtensionSlot.footerRight;
    case 'secondaryPanel':
      return ShellExtensionSlot.secondaryPanel;
    default:
      return ShellExtensionSlot.topBarActions;
  }
}
