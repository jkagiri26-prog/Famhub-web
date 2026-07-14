/// ============================================================
/// FAMHUB SDK DEPRECATION REGISTRY
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/api/ = SDK API governance
///
/// Central registry for tracking all deprecated SDK APIs.
///
/// ✅ Deprecation Policy:
///   - Phase 1: Add @Deprecated with migration hint (current version)
///   - Phase 2: Remove in NEXT major version (e.g., 2.0.0)
///   - NEVER remove in the same major version
///
/// 🔮 Example:
///   ```dart
///   @Deprecated('Use canExecute() instead. Will be removed in 2.0.0')
///   @sdkMethod(version: '1.0.0')
///   bool hasPermission(String permission) =>
///       _canExecute(permission);
///   ```
///
/// This registry enables CI tools to:
///   1. Track all @Deprecated annotations in the SDK
///   2. Enforce minimum deprecation windows before removal
///   3. Generate migration reports for feature modules
/// ============================================================
library;

/// ============================================================
/// SDK Deprecation
///
/// Wrapper around Dart's @Deprecated with SDK-specific metadata.
///
/// Usage:
///   ```dart
///   @sdkDeprecated(
///     message: 'Use canExecute() instead',
///     removeIn: '2.0.0',
///     since: '1.0.0',
///   )
///   ```
/// ============================================================
class SdkDeprecated {
  /// Migration instruction for consumers
  final String message;

  /// The version when this will be removed (e.g., '2.0.0')
  final String removeIn;

  /// The version when this was deprecated
  final String since;

  const SdkDeprecated({
    required this.message,
    required this.removeIn,
    this.since = '1.0.0',
  });
}

/// ============================================================
/// Active deprecations — registry of all deprecated SDK APIs.
///
/// These are recorded here so CI can:
///   - Enforce that no deprecated API is used in new code
///   - Generate a deprecation report for the next major release
/// ============================================================
class SdkDeprecationRegistry {
  /// List of all currently deprecated SDK entries
  static const List<_DeprecatedEntry> entries = [
    // ─────────────────────────────────────────────────────────
    // Navigation SDK
    // ─────────────────────────────────────────────────────────
    _DeprecatedEntry(
      target: 'NavigationSdk.pop()',
      message: 'Use popWithResult() instead',
      removeIn: '2.0.0',
      since: '1.0.0',
    ),

    // ─────────────────────────────────────────────────────────
    // Capability SDK
    // ─────────────────────────────────────────────────────────
    _DeprecatedEntry(
      target: 'CapabilitySdk.canUseAI()',
      message: 'Use AccessSdk.canUseAI() instead',
      removeIn: '2.0.0',
      since: '1.0.0',
    ),
  ];

  /// Check if a specific SDK API is deprecated
  static bool isDeprecated(String target) =>
      entries.any((e) => e.target == target);

  /// Get the deprecation entry for a specific API
  static _DeprecatedEntry? entryFor(String target) {
    try {
      return entries.firstWhere((e) => e.target == target);
    } catch (_) {
      return null;
    }
  }

  /// Get all APIs that will be removed in the next major version
  static List<_DeprecatedEntry> scheduledForRemoval(String version) =>
      entries.where((e) => e.removeIn == version).toList();
}

/// Internal value object for deprecation tracking
class _DeprecatedEntry {
  final String target;
  final String message;
  final String removeIn;
  final String since;

  const _DeprecatedEntry({
    required this.target,
    required this.message,
    required this.removeIn,
    required this.since,
  });
}
