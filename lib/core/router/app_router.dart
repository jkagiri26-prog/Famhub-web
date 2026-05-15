import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shell/unified_app_shell.dart';
import '../dashboard/presentation/pages/unified_dashboard_host.dart';
import '../../../features/farm_management/presentation/farm_dashboard_page.dart';

class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: '/',

      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return AppShell(child: child);
          },

          routes: [

            /// 🏠 ROOT DASHBOARD (PRIMARY ENTRY)
            GoRoute(
              path: '/',
              builder: (context, state) {
                return const UnifiedDashboardHost();
              },
            ),

            /// 🚜 FARM MODULE (DEEP LINK ONLY - NOT PRIMARY NAV)
            GoRoute(
              path: '/farm',
              builder: (context, state) {
                return const FarmDashboardPage();
              },
            ),

          ],
        ),
      ],

      errorBuilder: (context, state) {
        return const Scaffold(
          body: Center(child: Text("Route not found")),
        );
      },
    );
  }
}