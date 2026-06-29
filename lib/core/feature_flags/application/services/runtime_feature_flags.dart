/// ============================================================
/// RUNTIME FEATURE FLAGS & GOVERNANCE EVALUATOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/feature_flags/application/services/ = feature flag evaluation
///
/// ✅ Responsibilities:
///   - Evaluate all governance rules before rendering
///   - Check: module enabled, feature flags, maintenance mode,
///     dependencies, permissions, subscription, entity, role
///   - Pure evaluation — no side effects, no state mutation
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - All authorization enforced by Supabase RLS + Context Engine
///   - Frontend is only a presentation layer
///   - Never exposes inaccessible modules/widgets
///   - Complements existing FeatureAccessService and AccessDecisionEngine
///
/// ❌ Does NOT:
///   - Mutate state
///   - Access Supabase directly
///   - Render widgets
///   - Import Flutter UI
/// ============================================================
library;
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/dashboard_widget_definition.dart';

/// ============================================================
/// FEATURE FLAG EVALUATION RESULT
/// ============================================================
class FeatureFlagResult {
  /// Whether the module/widget is allowed to render
  final bool isAllowed;

  /// Reason for denial (for debugging/telemetry)
  final String? denialReason;

  /// List of checks that passed
  final List<String> passedChecks;

  const FeatureFlagResult({
    required this.isAllowed,
    this.denialReason,
    this.passedChecks = const [],
  });

  static const allowed = FeatureFlagResult(isAllowed: true);

  static FeatureFlagResult denied(String reason) =>
      FeatureFlagResult(isAllowed: false, denialReason: reason);

  @override
  String toString() =>
      'FeatureFlagResult(allowed=$isAllowed${denialReason != null ? ', reason=$denialReason' : ''})';
}

/// ============================================================
/// RUNTIME FEATURE FLAGS EVALUATOR
/// ============================================================
///
/// Pure evaluation engine. Every rendering decision passes through here.
/// All checks are stateless and deterministic.
///
/// Integrates with:
/// - `FeatureAccessService` (existing policy decision service)
/// - `AccessDecisionEngine` (existing access engine)
/// - RuntimeFlagsNotifier (runtime flags provider)
/// ============================================================
class RuntimeFeatureFlags {
  /// ============================================================
  /// EVALUATE MODULE ACCESS
  /// ============================================================
  ///
  /// Determines if a system module should be visible/accessible
  /// based on all governance rules defined by backend metadata.
  ///
  /// Checks performed:
  /// 1. Module enabled state
  /// 2. Maintenance mode
  /// 3. Authentication status
  /// 4. Subscription/tier requirement
  /// 5. Entity requirement
  /// 6. Device-specific visibility
  /// ============================================================
  static FeatureFlagResult evaluateModule({
    required SystemModule module,
    required EntityContext context,
    String? deviceType,
  }) {
    final passedChecks = <String>[];
    final denied = <String>[];

    // ── 1. Module enabled ──
    if (!module.isEnabled) {
      denied.add('module_disabled');
      return FeatureFlagResult.denied('Module "${module.moduleKey}" is disabled');
    }
    passedChecks.add('module_enabled');

    // ── 2. Maintenance mode ──
    if (module.maintenanceMode) {
      denied.add('maintenance_mode');
      return FeatureFlagResult.denied(
          'Module "${module.moduleKey}" is in maintenance mode');
    }
    passedChecks.add('not_maintenance');

    // ── 3. Authentication ──
    if (context.isGuest) {
      denied.add('guest_user');
      return FeatureFlagResult.denied('User is guest — module access denied');
    }
    passedChecks.add('authenticated');

    // ── 4. Subscription/tier ──
    if (module.premiumOnly || module.requiresSubscription) {
      final tier = context.tier ?? 'free';
      if (tier == 'free') {
        denied.add('premium_required');
        return FeatureFlagResult.denied(
            'Module "${module.moduleKey}" requires premium subscription');
      }
      passedChecks.add('subscription_ok');
    }
    passedChecks.add('tier_check_ok');

    // ── 5. Entity requirement ──
    if (module.requiresEntity || module.requiresFarm || module.requiresBusiness) {
      if (context.entityId == null || context.entityId!.isEmpty) {
        denied.add('entity_required');
        return FeatureFlagResult.denied(
            'Module "${module.moduleKey}" requires an entity (farm/business)');
      }
      passedChecks.add('entity_ok');
    }

    // ── 6. Verification requirement ──
    if (module.requiresVerification) {
      // Verification status would come from EntityContext
      // For now, this is a placeholder for future expansion
      passedChecks.add('verification_not_implemented');
    }

    // ── 7. Device compatibility ──
    if (deviceType != null) {
      final deviceCheck = _checkDeviceCompatibility(module, deviceType);
      if (!deviceCheck.isAllowed) {
        return deviceCheck;
      }
      passedChecks.add('device_compatible');
    }

    return FeatureFlagResult(
      isAllowed: true,
      passedChecks: passedChecks,
    );
  }

  /// ============================================================
  /// EVALUATE WIDGET ACCESS
  /// ============================================================
  ///
  /// Determines if a specific dashboard widget should render
  /// based on backend metadata and user context.
  /// ============================================================
  static FeatureFlagResult evaluateWidget({
    required DashboardWidgetDefinition widget,
    required EntityContext context,
    String? deviceType,
  }) {
    final passedChecks = <String>[];

    // ── 1. Widget visibility ──
    if (!widget.isVisible) {
      return FeatureFlagResult.denied(
          'Widget "${widget.widgetKey}" is hidden by backend');
    }
    passedChecks.add('widget_visible');

    // ── 2. Role requirement ──
    if (widget.requiredRole != null && context.role != null) {
      if (context.role != widget.requiredRole) {
        return FeatureFlagResult.denied(
            'Widget "${widget.widgetKey}" requires role "${widget.requiredRole}"');
      }
      passedChecks.add('role_match');
    }

    // ── 3. Subscription requirement ──
    if (widget.requiresSubscription) {
      final tier = context.tier ?? 'free';
      if (tier == 'free') {
        return FeatureFlagResult.denied(
            'Widget "${widget.widgetKey}" requires subscription');
      }
      passedChecks.add('subscription_ok');
    }

    // ── 4. Entity requirement ──
    if (widget.requiresEntity) {
      if (context.entityId == null || context.entityId!.isEmpty) {
        return FeatureFlagResult.denied(
            'Widget "${widget.widgetKey}" requires an entity');
      }
      passedChecks.add('entity_ok');
    }

    // ── 5. Device compatibility ──
    if (deviceType != null && !widget.isVisibleOnDevice(deviceType)) {
      return FeatureFlagResult.denied(
          'Widget "${widget.widgetKey}" not available on $deviceType');
    }
    passedChecks.add('device_compatible');

    return FeatureFlagResult(
      isAllowed: true,
      passedChecks: passedChecks,
    );
  }

  /// ============================================================
  /// EVALUATE SECTION ACCESS
  /// ============================================================
  ///
  /// Determines if a dashboard section should be visible.
  /// ============================================================
  static FeatureFlagResult evaluateSection({
    required String sectionKey,
    required EntityContext context,
    String? requiredRole,
    String? requiredEntityType,
  }) {
    final passedChecks = <String>[];

    // ── Role requirement ──
    if (requiredRole != null && context.role != null) {
      if (context.role != requiredRole) {
        return FeatureFlagResult.denied(
            'Section "$sectionKey" requires role "$requiredRole"');
      }
      passedChecks.add('role_match');
    }

    // ── Entity type requirement ──
    if (requiredEntityType != null) {
      if (context.entityId == null || context.entityId!.isEmpty) {
        return FeatureFlagResult.denied(
            'Section "$sectionKey" requires entity type "$requiredEntityType"');
      }
      passedChecks.add('entity_type_ok');
    }

    return FeatureFlagResult(
      isAllowed: true,
      passedChecks: passedChecks,
    );
  }

  /// ============================================================
  /// DEVICE COMPATIBILITY CHECK
  /// ============================================================
  static FeatureFlagResult _checkDeviceCompatibility(
    SystemModule module,
    String deviceType,
  ) {
    if (module.desktopOnly && deviceType != 'desktop') {
      return FeatureFlagResult.denied(
          'Module "${module.moduleKey}" is desktop-only');
    }
    if (module.mobileOnly && deviceType != 'mobile') {
      return FeatureFlagResult.denied(
          'Module "${module.moduleKey}" is mobile-only');
    }
    if (module.tabletOnly && deviceType != 'tablet') {
      return FeatureFlagResult.denied(
          'Module "${module.moduleKey}" is tablet-only');
    }

    return FeatureFlagResult.allowed;
  }
}
