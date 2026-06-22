/// ============================================================
/// MODULE CONTRACT (PURE ABSTRACT DEFINITION)
/// ============================================================
///
/// SYSTEM/MODULES_CONTROL = SYSTEM GOVERNANCE LAYER
///
/// Pure abstract contract for module definitions.
///
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:flutter/material.dart';

/// ============================================================
/// APP MODULE CONTRACT
/// ============================================================
///
/// Defines the pure contract every module must implement.
/// ============================================================
abstract class AppModule {
  /// Identity
  String get name;
  String get route;

  /// Optional grouping metadata
  String? get group => null;

  /// Role access control (static role list)
  List<String> get allowedRoles;

  /// Widget keys this module exposes to dashboard engine
  List<String> get dashboardWidgets;
}

/// ============================================================
/// MODULE CONTRACT
/// ============================================================
///
/// Concrete module registration contract used by feature modules
/// that follow the register() pattern. Provides UI-level
/// metadata for runtime module discovery and rendering.
/// ============================================================
class ModuleContract {
  /// Module identifier key
  final String key;

  /// Human-readable display name
  final String name;

  /// Module description
  final String description;

  /// Icon for navigation and dashboard display
  final IconData icon;

  /// Builder function to create the module's page widget
  final WidgetBuilder builder;

  const ModuleContract({
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.builder,
  });
}
