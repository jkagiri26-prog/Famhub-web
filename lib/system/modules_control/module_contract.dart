import 'package:flutter/widgets.dart';

abstract class AppModule {
  String get name;
  String get route;

  /// Entry widget (lazy)
  Widget build();

  /// Optional dashboard widgets
  List<String> get dashboardWidgets => [];

  /// Role access
  List<String> get allowedRoles;
}