import 'package:flutter/widgets.dart';

abstract class AppModule {
  /// Identity
  String get name;
  String get route;

  /// ============================================================
  /// DECLARATIVE UI DEFINITION ONLY
  /// ============================================================

  /// Widget keys this module exposes to dashboard engine
  List<String> get dashboardWidgets;

  /// Optional grouping metadata
  String? get group => null;

  /// Role access control
  List<String> get allowedRoles;

  /// ============================================================
  /// MAIN ENTRY WIDGET (APP ROUTING ONLY)
  /// ============================================================
  Widget build();
}