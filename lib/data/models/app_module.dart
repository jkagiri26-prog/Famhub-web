import 'package:flutter/material.dart';

enum ModuleType { dashboard, feature }

enum ModuleStatus { active, disabled, maintenance, beta }

class AppModule {
  final String title;
  final IconData icon;
  final String route;
  final WidgetBuilder builder;
  final List<String> roles;
  final ModuleType type;
  final ModuleStatus status;

  const AppModule({
    required this.title,
    required this.icon,
    required this.route,
    required this.builder,
    required this.roles,
    this.type = ModuleType.feature,
    this.status = ModuleStatus.active,
  });
}