import 'package:famhub_app/core/dashboard_engine/domain/models/layout_context.dart';

/// ============================================================
/// LAYOUT RULE ENGINE (PURE POLICY LAYER)
/// ============================================================
///
/// Determines WHICH presetKey should be used.
///
/// ❌ NOT responsible for:
/// - UI layout definitions
/// - module control logic
/// - registry decisions
/// ============================================================
class LayoutRuleResult {
  final String presetKey;

  /// Optional traceability (useful for debugging / AI scoring later)
  final String sourceRule;

  const LayoutRuleResult({
    required this.presetKey,
    required this.sourceRule,
  });
}

/// ============================================================
/// PURE LAYOUT RULES (DETERMINISTIC DECISION ENGINE)
/// ============================================================
class LayoutRules {
  static LayoutRuleResult resolve({
    required LayoutContext context,
  }) {
    // ============================================================
    // 1. ENTITY OVERRIDE (HIGHEST PRIORITY)
    // ============================================================
    if (context.entityId != null) {
      return const LayoutRuleResult(
        presetKey: 'default_grid',
        sourceRule: 'entity_override',
      );
    }

    // ============================================================
    // 2. ROLE OVERRIDE
    // ============================================================
    if (context.role == 'admin') {
      return const LayoutRuleResult(
        presetKey: 'desktop_split',
        sourceRule: 'role_admin',
      );
    }

    // ============================================================
    // 3. DEVICE FALLBACK
    // ============================================================
    switch (context.device) {
      case LayoutDeviceType.mobile:
        return const LayoutRuleResult(
          presetKey: 'mobile_stack',
          sourceRule: 'device_mobile',
        );

      case LayoutDeviceType.tablet:
        return const LayoutRuleResult(
          presetKey: 'tablet_mix',
          sourceRule: 'device_tablet',
        );

      case LayoutDeviceType.desktop:
        return const LayoutRuleResult(
          presetKey: 'desktop_split',
          sourceRule: 'device_desktop',
        );
    }

    // ============================================================
    // 4. SAFETY FALLBACK
    // ============================================================
    return const LayoutRuleResult(
      presetKey: 'default_grid',
      sourceRule: 'fallback_default',
    );
  }
}