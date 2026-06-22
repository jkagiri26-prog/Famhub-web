import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../config/permissions.dart';
import '../presentation/pages/auth_page.dart';

class AuthModule extends AppModule {
  static const String moduleId = 'auth';
  static const String displayName = 'Authentication';
  static const IconData icon = Icons.security;

  AuthModule();

  void ensureInitialized() {
    // TODO: Initialize registry if needed
  }

  List<String> get permissions => [];

  Map<String, WidgetBuilder> get routes => {
        '/auth': (_) => const AuthPage(),
      };

  @override
  String get name => moduleId;

  @override
  String get route => '/auth';

  @override
  List<String> get allowedRoles => const [
        'guest',
        'farmer',
        'trader',
        'stakeholder',
      ];

  @override
  List<String> get dashboardWidgets => const [];

    Widget build() {
    ensureInitialized();
    return const AuthPage();
  }
}
