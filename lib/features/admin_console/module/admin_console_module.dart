import 'package:flutter/material.dart';
import 'package:famhub_app/system/modules_control/module_contract.dart';
import 'package:famhub_app/features/admin_console/presentation/pages/admin_dashboard_page.dart';

class AdminConsoleModule extends AppModule {
  @override
  String get name => 'admin_console';

  @override
  String get route => '/admin';

  @override
  List<String> get allowedRoles => ['admin'];

  @override
  List<String> get dashboardWidgets => [];
}