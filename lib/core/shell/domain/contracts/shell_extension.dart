/// ============================================================
/// SHELL EXTENSION CONTRACT — Future extension points
/// ============================================================
///
/// 🎯 PURPOSE:
///   Define the contract for shell extension points. Modules
///   contribute widgets to these slots without the shell ever
///   knowing what the widget represents. The shell simply renders
///   registered extensions in the appropriate region.
///
/// ✅ Domain-Agnostic:
///   - Shell never knows what a widget represents
///   - No business logic in extensions
///   - AI Assistant, Wallet, Rewards, Chat, Context Switcher,
///     Global Search, Command Palette, Notifications, System Health,
///     User Presence — all possible future extensions
///
/// ✅ Extension Principles:
///   - Shell must not import feature modules
///   - Modules must not directly modify shell internals
///   - All integration through configuration or extension contracts
/// ============================================================
library;

import 'package:flutter/material.dart';

/// ============================================================
/// SHELF EXTENSION SLOT — Which region an extension belongs to
/// ============================================================
enum ShellExtensionSlot {
  /// Top bar: right side actions area (AI, search, etc.)
  topBarLeading,

  /// Top bar: right side actions area (AI, search, etc.)
  topBarActions,

  /// Top bar: trailing area (profile, settings, etc.)
  topBarTrailing,

  /// Navigation: additional items above main nav
  navigationTop,

  /// Navigation: additional items below main nav
  navigationBottom,

  /// Content: above main content
  contentTop,

  /// Content: below main content
  contentBottom,

  /// Floating area: additional floating widgets
  floatingArea,

  /// Overlay area: panels, dialogs, sheets
  overlayArea,

  /// Status bar: left side items
  statusBarLeft,

  /// Status bar: right side items
  statusBarRight,

  /// Footer: left side items
  footerLeft,

  /// Footer: right side items
  footerRight,

  /// Secondary panel: content area
  secondaryPanel,
}

/// ============================================================
/// SHELL EXTENSION — A widget contributed to a shell slot
/// ============================================================
///
/// Modules create instances of this and register them via
/// runtime module descriptors (not static registry).
///
/// The shell reads extensions from shellExtensionProvider (Riverpod)
/// which is driven by the platform's module runtime (composition layer).
///
/// 🎯 Usage (modern — runtime-driven):
///   Modules contribute ShellExtensionDescriptors in their
///   ModuleRuntimeDescriptor. The composition engine resolves
///   them and the shellExtensionProvider converts them.
///
/// 🚫 Usage (legacy — deprecated):
///   ShellExtensionRegistry.register(...) — still works but
///   is superseded by the runtime-driven provider.
///
/// The shell never reads [id] for rendering — it's only for
/// deduplication and ordering.
///
/// Note: The builder should be provided by the module at runtime.
/// Runtime-driven extensions use a placeholder builder that is
/// replaced when the module's widget resolver is available.
///
/// Example:
/// ```dart
/// ShellExtension(
///   id: 'ai_assistant',
///   slot: ShellExtensionSlot.topBarActions,
///   priority: 10,
///   builder: (context) => AIAssistantButton(),
/// );
/// ```
/// ============================================================
class ShellExtension {
  /// Unique identifier for this extension (used for dedup)
  final String id;

  /// Which region slot this extension belongs to
  final ShellExtensionSlot slot;

  /// Priority for ordering (lower = higher priority)
  final int priority;

  /// Builder function that creates the extension widget
  final Widget Function(BuildContext context) builder;

  /// Optional feature flag key for runtime evaluation
  String? extensionKey;

  // Non-const to allow extensionKey to be set post-construction
  ShellExtension({
    required this.id,
    required this.slot,
    this.priority = 100,
    required this.builder,
    this.extensionKey,
  });
}

/// ============================================================
/// SHELL EXTENSION REGISTRY (LEGACY) — Static registry
/// ============================================================
///
/// ⚠️ DEPRECATED: Use shellExtensionProvider instead.
///
/// The static registry is maintained for backward compatibility.
/// All new extensions should use ModuleRuntimeDescriptor.shellExtensions
/// and the runtime-driven shellExtensionProvider.
///
/// Modules that still use this registry will continue to work,
/// but their extensions will not participate in:
///   - Module governance (disable/enable)
///   - Maintenance mode auto-hide
///   - Feature flag evaluation
///   - Hot-reload module updates
///
/// To migrate: add ShellExtensionDescriptor to ModuleRuntimeDescriptor
/// instead of calling ShellExtensionRegistry.register().
/// ============================================================
class ShellExtensionRegistry {
  static final List<ShellExtension> _extensions = [];

  /// Register a shell extension
  static void register(ShellExtension extension) {
    _extensions.removeWhere((e) => e.id == extension.id);
    _extensions.add(extension);
    _extensions.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Get all extensions for a given slot
  static List<ShellExtension> forSlot(ShellExtensionSlot slot) {
    return _extensions.where((e) => e.slot == slot).toList();
  }

  /// Get all registered extensions
  static List<ShellExtension> get all => List.unmodifiable(_extensions);

  /// Clear all extensions (for testing)
  static void clear() => _extensions.clear();

  /// Remove a specific extension by id
  static void unregister(String id) {
    _extensions.removeWhere((e) => e.id == id);
  }
}
