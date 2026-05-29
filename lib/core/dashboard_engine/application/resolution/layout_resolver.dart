import 'layout_rules.dart';
import 'layout_presets.dart';
import '../../domain/models/layout_context.dart';

/// ============================================================
/// LAYOUT RESOLUTION RESULT
/// ============================================================
///
/// Final resolved layout preset.
/// ============================================================
class LayoutResolution {
  final LayoutPreset preset;

  const LayoutResolution({
    required this.preset,
  });
}

/// ============================================================
/// LAYOUT RESOLVER (ORCHESTRATION LAYER)
/// ============================================================
///
/// Coordinates:
/// - LayoutRules (decision layer)
/// - LayoutPresets (fallback catalog)
///
/// ❌ Does NOT contain business logic
/// ❌ Does NOT define rules
/// ============================================================
class LayoutResolver {
  final List<LayoutPreset> presets;

  const LayoutResolver({
    this.presets = LayoutPresets.defaults,
  });

  /// ============================================================
  /// RESOLVE FINAL LAYOUT
  /// ============================================================
  LayoutResolution resolve({
    required LayoutContext context,
  }) {
    final rule = LayoutRules.resolve(context: context);

    final preset = _resolvePresetSafely(rule.presetKey);

    return LayoutResolution(
      preset: preset,
    );
  }

  /// ============================================================
  /// SAFE PRESET MATCHING (NO EXCEPTIONS)
  /// ============================================================
  LayoutPreset _resolvePresetSafely(String presetKey) {
    final match = presets.where((p) => p.key == presetKey);

    if (match.isNotEmpty) {
      return match.first;
    }

    return LayoutPresets.getDefault();
  }
}