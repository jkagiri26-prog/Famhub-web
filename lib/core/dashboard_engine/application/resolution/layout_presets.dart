/// ============================================================
/// LAYOUT PRESETS (STATIC FALLBACK CATALOG)
/// ============================================================
///
/// Pure static definitions used ONLY as fallback options
/// in LayoutResolver.
///
/// ❌ NOT a runtime decision system
/// ❌ NOT a registry
/// ❌ NOT dynamic configuration
/// ❌ NOT allowed to contain logic or state
/// ============================================================
library;

/// ============================================================
/// LAYOUT TYPE (STATIC ENUM ONLY)
/// ============================================================
///
/// Defines structural layout families.
/// This is NOT a decision engine.
/// ============================================================
enum LayoutType {
  grid,
  split,
  stacked,
  mixed,
}

/// ============================================================
/// LAYOUT PRESET (IMMUTABLE STRUCTURE ONLY)
/// ============================================================
///
/// Represents a named layout configuration.
/// No logic, no computation, no behavior.
/// ============================================================
class LayoutPreset {
  final String key;
  final String name;
  final LayoutType type;

  /// Marks default fallback preset only
  final bool isDefault;

  const LayoutPreset({
    required this.key,
    required this.name,
    required this.type,
    this.isDefault = false,
  });
}

/// ============================================================
/// LAYOUT PRESETS (STATIC FALLBACK CATALOG ONLY)
/// ============================================================
///
/// This class is a READ-ONLY catalog.
/// It must never become a registry or runtime system.
/// ============================================================
class LayoutPresets {
  static const List<LayoutPreset> defaults = [
    LayoutPreset(
      key: 'default_grid',
      name: 'Default Grid',
      type: LayoutType.grid,
      isDefault: true,
    ),
    LayoutPreset(
      key: 'desktop_split',
      name: 'Desktop Split',
      type: LayoutType.split,
    ),
    LayoutPreset(
      key: 'mobile_stack',
      name: 'Mobile Stack',
      type: LayoutType.stacked,
    ),
    LayoutPreset(
      key: 'tablet_mix',
      name: 'Tablet Mixed',
      type: LayoutType.mixed,
    ),
  ];

  /// ============================================================
  /// DEFAULT FALLBACK (STATIC SAFE ACCESS ONLY)
  /// ============================================================
  static LayoutPreset getDefault() {
    return defaults.firstWhere(
      (e) => e.isDefault,
      orElse: () => defaults.first,
    );
  }
}