import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ============================================================
/// DASHBOARD COMPOSER CONTRACT (LEGACY FALLBACK ONLY)
/// ============================================================
///
/// ⚠️ DO NOT use for production dashboard rendering.
///
/// This interface exists ONLY for:
/// - emergency fallback UIs
/// - modules not yet migrated to descriptor system
/// - offline / bootstrap states
///
/// Primary system is:
/// Descriptor → Renderer → Widget Registry
/// ============================================================

abstract class DashboardComposerContract {
  /// Logical module identifier
  String get moduleKey;

  /// ⚠️ Legacy UI builder (bypasses descriptor system)
  List<Widget> build(WidgetRef ref);

  /// Optional hook for migration safety
  bool get isLegacy => true;
}