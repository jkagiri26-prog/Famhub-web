/// ============================================================
/// CAPABILITY LEVEL — GRADUATED OPERATIONAL DEPTH
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/domain/ = capability domain models
///
/// Capability levels define graduated depth for a capability.
/// Each level adds increasing operational sophistication.
///
/// The registry owns the level definitions — they are NOT
/// hardcoded in business logic.
///
/// Example — workflow.execution:
///   Level 0: Disabled
///   Level 1: Activity Only
///   Level 2: Activity + Inventory
///   Level 3: Activity + Inventory + Financials
///   Level 4: Activity + Inventory + Financials + KPIs
///   Level 5: Activity + Inventory + Financials + KPIs + Automation
///   Level 6: Full AI Optimization
///
/// ✅ Responsibilities:
///   - Define a level number and its human meaning
///   - Be owned by the registry, not hardcoded
///   - Pure declaration
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Evaluate capability state
///   - Import UI
/// ============================================================
library;

/// ============================================================
/// CAPABILITY LEVEL
/// ============================================================
///
/// A named level for a capability, with increasing depth.
/// Levels are defined in the registry and can vary per capability.
/// ============================================================
class CapabilityLevel {
  /// Numeric level (0 = disabled, higher = deeper)
  final int level;

  /// Human-readable name for this level
  final String name;

  /// Description of what this level enables
  final String description;

  const CapabilityLevel({
    required this.level,
    required this.name,
    this.description = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapabilityLevel &&
          runtimeType == other.runtimeType &&
          level == other.level;

  @override
  int get hashCode => level.hashCode;

  @override
  String toString() => 'CapabilityLevel($level: $name)';
}

/// ============================================================
/// CAPABILITY LEVEL PRESETS
/// ============================================================
///
/// Standard level configurations for common capability patterns.
/// Each capability in the registry selects its own level scheme.
/// ============================================================
abstract final class CapabilityLevelPresets {
  CapabilityLevelPresets._();

  /// Standard 7-level progression (0-6) for workflow-like capabilities.
  static const List<CapabilityLevel> workflowLevels = [
    CapabilityLevel(
      level: 0,
      name: 'Disabled',
      description: 'Capability is not available',
    ),
    CapabilityLevel(
      level: 1,
      name: 'Activity Only',
      description: 'Basic activity recording without extended data',
    ),
    CapabilityLevel(
      level: 2,
      name: 'With Inventory',
      description: 'Activity recording + inventory tracking',
    ),
    CapabilityLevel(
      level: 3,
      name: 'With Financials',
      description: 'Activity + inventory + financial recording',
    ),
    CapabilityLevel(
      level: 4,
      name: 'With KPIs',
      description: 'Activity + inventory + financials + KPI tracking',
    ),
    CapabilityLevel(
      level: 5,
      name: 'With Automation',
      description: 'Activity + inventory + financials + KPIs + automation',
    ),
    CapabilityLevel(
      level: 6,
      name: 'Full AI Optimization',
      description: 'Full AI-driven optimization and recommendations',
    ),
  ];

  /// Simple on/off (Level 0 = off, Level 1 = on).
  static const List<CapabilityLevel> binaryLevels = [
    CapabilityLevel(
      level: 0,
      name: 'Disabled',
      description: 'Capability is not available',
    ),
    CapabilityLevel(
      level: 1,
      name: 'Enabled',
      description: 'Capability is fully available',
    ),
  ];

  /// Three-tier: Disabled, Basic, Advanced.
  static const List<CapabilityLevel> threeTierLevels = [
    CapabilityLevel(
      level: 0,
      name: 'Disabled',
      description: 'Capability is not available',
    ),
    CapabilityLevel(
      level: 1,
      name: 'Basic',
      description: 'Basic access to capability',
    ),
    CapabilityLevel(
      level: 2,
      name: 'Advanced',
      description: 'Advanced access with additional features',
    ),
  ];

  /// Analytics-specific levels.
  static const List<CapabilityLevel> analyticsLevels = [
    CapabilityLevel(
      level: 0,
      name: 'Disabled',
      description: 'Analytics not available',
    ),
    CapabilityLevel(
      level: 1,
      name: 'Basic Dashboard',
      description: 'Pre-built analytics dashboard with standard metrics',
    ),
    CapabilityLevel(
      level: 2,
      name: 'Custom Reports',
      description: 'Custom report builder with filtered views',
    ),
    CapabilityLevel(
      level: 3,
      name: 'Predictive Analytics',
      description: 'AI-driven forecasts and predictive insights',
    ),
  ];
}
