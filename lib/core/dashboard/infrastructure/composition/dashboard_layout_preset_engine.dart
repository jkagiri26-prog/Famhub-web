import '../models/dashboard_layout_preset.dart';

class DashboardLayoutPresetEngine {
  final List<DashboardLayoutPreset> presets;

  DashboardLayoutPresetEngine({
    required this.presets,
  });

  DashboardLayoutPreset resolve({
    required String? selectedKey,
    required String deviceType,
  }) {
    /// Guard: empty presets fallback
    if (presets.isEmpty) {
      throw StateError(
        'DashboardLayoutPresetEngine: No presets provided',
      );
    }

    /// ------------------------------------------------------------
    /// 1. EXPLICIT SELECTION (HIGHEST PRIORITY)
    /// ------------------------------------------------------------
    if (selectedKey != null) {
      final match = presets.where(
        (p) => p.key == selectedKey,
      );

      if (match.isNotEmpty) {
        return match.first;
      }
    }

    /// ------------------------------------------------------------
    /// 2. DEVICE-AWARE MATCHING (STRICT)
    /// ------------------------------------------------------------
    final deviceMatch = presets.where((p) {
      return _matchesDevice(p.layoutType, deviceType);
    }).toList();

    if (deviceMatch.isNotEmpty) {
      return deviceMatch.first;
    }

    /// ------------------------------------------------------------
    /// 3. DEFAULT FLAG (SAFE FALLBACK)
    /// ------------------------------------------------------------
    final defaultMatch = presets.where(
      (p) => p.isDefault,
    );

    if (defaultMatch.isNotEmpty) {
      return defaultMatch.first;
    }

    /// ------------------------------------------------------------
    /// 4. FINAL FALLBACK (FIRST ENTRY)
    /// ------------------------------------------------------------
    return presets.first;
  }

  // ============================================================
  // DEVICE MATCHING RULE ENGINE
  // ============================================================
  bool _matchesDevice(String layoutType, String deviceType) {
    switch (deviceType) {
      case 'mobile':
        return layoutType.contains('mobile') ||
            layoutType.contains('stack');

      case 'tablet':
        return layoutType.contains('tablet') ||
            layoutType.contains('mixed');

      case 'desktop':
        return layoutType.contains('desktop') ||
            layoutType.contains('split');

      default:
        return false;
    }
  }
}