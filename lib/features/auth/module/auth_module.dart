import 'package:flutter/material.dart';

import '../../../system/module/module_contract.dart';
import '../config/permissions.dart';
import '../presentation/pages/auth_page.dart';

class AuthModule extends AppModule {
  static const String moduleId = 'auth';
  static const String displayName = 'Authentication';
  static const IconData icon = Icons.security;

  const AuthModule();

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

  @override
  Widget build() {
    ensureInitialized();
    return const AuthPage();
  }
}
