/// ============================================================
/// TEXT STYLES — Centralized typography system
/// ============================================================
///
/// 🎯 PURPOSE:
///   Define reusable text styles consumed by the shell and modules.
///   No hardcoded colors — colors come from ShellTheme.
///
/// ✅ Domain-Agnostic:
///   - Neutral font sizes and weights
///   - No agriculture-specific styles
///   - Modular productivity platform aesthetic
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'shell_theme.dart';

/// ============================================================
/// SHELL TEXT STYLES
/// ============================================================
class ShellTextStyles {
  // ── Headings ──
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.35,
  );

  // ── Body ──
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // ── Labels ──
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  // ── Caption / Meta ──
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  // ── Monospace ──
  static const TextStyle mono = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFamily: 'monospace',
    letterSpacing: -0.2,
  );

  // ── Apply palette colors to text styles ──
  static TextStyle withPalette(TextStyle style, ShellColorPalette palette) {
    return style.copyWith(
      color: palette.primaryText,
    );
  }

  static TextStyle withSecondary(TextStyle style, ShellColorPalette palette) {
    return style.copyWith(
      color: palette.secondaryText,
    );
  }

  static TextStyle withTertiary(TextStyle style, ShellColorPalette palette) {
    return style.copyWith(
      color: palette.tertiaryText,
    );
  }

  // ── Named text styles with theme colors ──
  static Map<String, TextStyle Function(ShellColorPalette)> get named => {
        'h1': (p) => h1.copyWith(color: p.primaryText),
        'h2': (p) => h2.copyWith(color: p.primaryText),
        'h3': (p) => h3.copyWith(color: p.primaryText),
        'h4': (p) => h4.copyWith(color: p.primaryText),
        'body': (p) => body.copyWith(color: p.primaryText),
        'bodyLarge': (p) => bodyLarge.copyWith(color: p.primaryText),
        'bodySmall': (p) => bodySmall.copyWith(color: p.secondaryText),
        'label': (p) => label.copyWith(color: p.primaryText),
        'labelSmall': (p) => labelSmall.copyWith(color: p.secondaryText),
        'caption': (p) => caption.copyWith(color: p.tertiaryText),
        'overline': (p) => overline.copyWith(color: p.tertiaryText),
        'mono': (p) => mono.copyWith(color: p.primaryText),
      };
}
