/// ============================================================
/// RUNTIME REASON — STRUCTURED DECISION EXPLANATION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/runtime_decision/domain/ = domain layer
///
/// Defines standard reason strings for every denied action.
/// These provide structured, explainable reasons for enterprise
/// support and government deployment compliance.
///
/// ✅ ARCHITECTURE PRINCIPLE:
///   Every denied action includes:
///     reason: Human-readable explanation
///     source: Which engine denied it
///     failedChecks: What specific rules/checks failed
///
/// ✅ USAGE:
///   Instead of:
///     return false; // "access denied"
///
///   Always use:
///     RuntimeDecision(
///       allowed: false,
///       reason: 'Workflow disabled by Kenya Agricultural Policy',
///       source: 'Policy Engine',
///       failedChecks: ['WORKFLOW_EXECUTION'],
///     );
/// ============================================================
library;

/// ============================================================
/// RUNTIME REASON CONSTANTS
/// ============================================================
///
/// Standardized reason strings organized by source engine.
/// ============================================================
class RuntimeReasons {
  // ── Capability Engine Reasons ──
  static const String capabilityNotAvailable =
      'Capability not available for this organization';
  static const String capabilityLevelTooLow =
      'Capability level too low for this action';
  static const String capabilityNotRegistered =
      'Capability not registered in the system';

  // ── Policy Engine Reasons ──
  static const String policyDenied =
      'Action denied by regional/location policy';
  static const String policyRestrictedRegion =
      'Restricted by regional policy';
  static const String policyLimitExceeded =
      'Policy limit exceeded for this action';

  // ── Access Engine Reasons ──
  static const String accessRoleDenied =
      'User role not permitted for this action';
  static const String accessUpgradeRequired =
      'Subscription upgrade required';
  static const String accessPolicyNotLoaded =
      'Access policy not yet loaded';
  static const String accessPermissionDenied =
      'Permission not granted for this action';

  // ── Feature Flag Reasons ──
  static const String featureDisabled =
      'Feature is disabled in current runtime context';
  static const String moduleInMaintenance =
      'Service is in maintenance mode';
  static const String moduleDisabled =
      'Service is disabled for this context';
  static const String guestNotAllowed =
      'Guest users are not allowed to perform this action';
  static const String entityRequired =
      'An entity (farm/business) is required for this action';
  static const String premiumRequired =
      'Premium subscription required for this action';
  static const String deviceNotCompatible =
      'Action not available on this device type';

  // ── Generic Reasons ──
  static const String engineNotAvailable =
      'Decision engine not available';
  static const String unknownAction =
      'Unknown action — no decision rules configured';
}

/// ============================================================
/// RUNTIME CHECK CODES
/// ============================================================
///
/// Standardized check codes for failedChecks list.
/// These can be used for telemetry, analytics, and debugging.
/// ============================================================
class RuntimeCheckCodes {
  // ── Capability Checks ──
  static const String CAPABILITY_NOT_FOUND = 'CAPABILITY_NOT_FOUND';
  static const String CAPABILITY_DISABLED = 'CAPABILITY_DISABLED';
  static const String CAPABILITY_LEVEL_INSUFFICIENT =
      'CAPABILITY_LEVEL_INSUFFICIENT';

  // ── Policy Checks ──
  static const String POLICY_DENIED = 'POLICY_DENIED';
  static const String POLICY_RESTRICTED = 'POLICY_RESTRICTED';
  static const String POLICY_LIMIT_EXCEEDED = 'POLICY_LIMIT_EXCEEDED';

  // ── Access Checks ──
  static const String ACCESS_ROLE_DENIED = 'ACCESS_ROLE_DENIED';
  static const String ACCESS_UPGRADE_REQUIRED =
      'ACCESS_UPGRADE_REQUIRED';
  static const String ACCESS_POLICY_NOT_LOADED =
      'ACCESS_POLICY_NOT_LOADED';
  static const String ACCESS_PERMISSION_DENIED =
      'ACCESS_PERMISSION_DENIED';

  // ── Feature Flag Checks ──
  static const String FEATURE_DISABLED = 'FEATURE_DISABLED';
  static const String MODULE_MAINTENANCE = 'MODULE_MAINTENANCE';
  static const String MODULE_DISABLED = 'MODULE_DISABLED';
  static const String GUEST_USER = 'GUEST_USER';
  static const String ENTITY_REQUIRED = 'ENTITY_REQUIRED';
  static const String PREMIUM_REQUIRED = 'PREMIUM_REQUIRED';
  static const String DEVICE_INCOMPATIBLE = 'DEVICE_INCOMPATIBLE';

  // ── Generic Checks ──
  static const String ENGINE_NOT_AVAILABLE = 'ENGINE_NOT_AVAILABLE';
  static const String UNKNOWN_ACTION = 'UNKNOWN_ACTION';
}

/// ============================================================
/// RUNTIME SOURCE NAMES
/// ============================================================
///
/// Standardized source engine names for the source field.
/// ============================================================
class RuntimeSources {
  static const String capabilityEngine = 'Capability Engine';
  static const String policyEngine = 'Policy Engine';
  static const String accessEngine = 'Access Engine';
  static const String featureFlags = 'Runtime Feature Flags';
  static const String runtimeDecision = 'Runtime Decision Engine';
  static const String unknown = 'Unknown';
}
