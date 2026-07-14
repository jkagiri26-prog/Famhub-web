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
/// 🎯 Usage (runtime-driven only):
///   Modules contribute ShellExtensionDescriptors in their
///   ModuleRuntimeDescriptor. The composition engine resolves
///   them and the shellExtensionProvider converts them.
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

