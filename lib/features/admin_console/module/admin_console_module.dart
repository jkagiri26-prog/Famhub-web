import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules/module.dart';
import 'package:famhub_app/features/admin_console/presentation/pages/admin_dashboard_page.dart';

class AdminConsoleModule extends AppModule {
  @override
  String get moduleKey => 'admin_console';

  @override
  String get moduleName => 'Admin Console';

  @override
  IconData get icon => Icons.admin_panel_settings;

  @override
  int get sortOrder => 999;

  @override
  bool get requiresAuth => true;

  @override
  bool get showInDashboard => true;

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardPage();
  }
}