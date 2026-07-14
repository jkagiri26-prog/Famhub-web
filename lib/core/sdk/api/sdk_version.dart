/// ============================================================
/// FAMHUB SDK VERSION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/api/ = SDK API governance
///
/// The SDK version is the SINGLE SOURCE OF TRUTH for API stability.
///
/// 🔮 Versioning Strategy:
///   MAJOR — Breaking API changes (removals, signature changes)
///   MINOR — New API additions (backward-compatible)
///   PATCH — Internal fixes, doc updates, deprecation notices
///
/// ✅ Future changes must update this file:
///   - 1.0.0 → 1.1.0 (new method added)
///   - 1.0.0 → 2.0.0 (breaking signature change)
///
/// ❌ NEVER change APIs silently. Always bump the version.
/// ============================================================
library;

/// ============================================================
/// THE one and only SDK version.
///
/// Used by:
///   - CI/CD pipeline for version reporting
///   - Feature modules to check SDK compatibility
///   - Deprecation notices to indicate when APIs were deprecated
/// ============================================================
class SdkVersion {
  /// MAJOR — Breaking changes
  static const int major = 1;

  /// MINOR — New features (backward-compatible)
  static const int minor = 0;

  /// PATCH — Fixes and documentation
  static const int patch = 0;

  /// The full semver string
  static const String current = '1.0.0';

  /// Build metadata (optional, e.g., 'beta', 'rc.1')
  static const String? build = null;

  /// Full version string including build metadata
  static String get full {
    if (build != null) return '$current+$build';
    return current;
  }

  /// Human-readable summary
  static String get summary => 'FAMHUB SDK v$current';

  /// Compare against another version (returns -1, 0, +1)
  static int compare(String otherVersion) {
    final parts = current.split('.');
    final otherParts = otherVersion.split('.');

    for (int i = 0; i < 3; i++) {
      final a = int.tryParse(parts[i]) ?? 0;
      final b = int.tryParse(otherParts[i]) ?? 0;
      if (a < b) return -1;
      if (a > b) return 1;
    }
    return 0;
  }

  /// Check if this SDK is compatible with a required minimum version
  static bool isCompatibleWith(String minimumVersion) {
    return compare(minimumVersion) >= 0;
  }
}
