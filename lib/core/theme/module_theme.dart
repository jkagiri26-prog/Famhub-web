/// ============================================================
/// MODULE THEME — Per-module content accents
/// ============================================================
///
/// The shell chrome (app bar + bottom navigation) always stays Vunio
/// green. Individual modules can tint their content — headings, tabs,
/// selected chips, icons and primary actions — to reflect their domain
/// while cards remain pure white for readability.
///
/// Usage:
/// ```dart
/// ModuleAccentScope(
///   accent: ModuleAccents.farm,
///   secondary: ModuleAccents.farmLivestock,
///   child: FarmManagementPage(),
/// )
/// ```
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'shell_theme_provider.dart';

/// Accent colours used inside module content areas.
class ModuleAccents {
  const ModuleAccents._();

  /// Brand default (Home and any module without a dedicated accent).
  static const Color home = FamhubBrandTokens.green;

  /// Commerce — warm terracotta from the isolated Vunio direction.
  static const Color marketplace = FamhubBrandTokens.marketplaceAccent;

  /// Farm — crop/olive green with a livestock brown secondary.
  static const Color farm = FamhubBrandTokens.farmCropAccent;
  static const Color farmLivestock = FamhubBrandTokens.farmLivestockAccent;

  /// AgriConnect — community blue, distinct from the farm greens.
  static const Color connect = FamhubBrandTokens.connectAccent;
}

/// Overrides only the accent slots of the current [ColorScheme].
///
/// Surfaces, backgrounds, borders and text remain the shell's cream /
/// white tokens, so cards stay white and readable.
class ModuleAccentScope extends StatelessWidget {
  final Color accent;
  final Color? secondary;
  final Widget child;

  const ModuleAccentScope({
    super.key,
    required this.accent,
    this.secondary,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final scheme = base.colorScheme;
    final secondaryAccent = secondary ?? accent;
    final onAccent = _onColor(accent);
    final onSecondary = _onColor(secondaryAccent);

    return Theme(
      data: base.copyWith(
        colorScheme: scheme.copyWith(
          primary: accent,
          onPrimary: onAccent,
          primaryContainer: accent.withValues(alpha: 0.12),
          onPrimaryContainer: accent,
          secondary: secondaryAccent,
          onSecondary: onSecondary,
          secondaryContainer: secondaryAccent.withValues(alpha: 0.12),
          onSecondaryContainer: secondaryAccent,
          tertiary: accent,
          onTertiary: onAccent,
        ),
      ),
      child: child,
    );
  }

  Color _onColor(Color color) =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
