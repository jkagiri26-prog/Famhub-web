import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/shell/presentation/pages/new_unified_app_shell.dart';
import 'package:famhub_app/core/shell/presentation/regions/unified_dashboard_host.dart';
import 'package:famhub_app/core/router/route_names.dart';

// ── Module pages (registry-driven imports) ──
import 'package:famhub_app/features/farm_management/presentation/pages/farm_dashboard_page.dart' as farm;
import 'package:famhub_app/features/marketplace/presentation/pages/marketplace_page.dart';
import 'package:famhub_app/features/analytics/presentation/pages/analytics_page.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_page.dart';
import 'package:famhub_app/features/logistics/presentation/pages/logistics_page.dart';
import 'package:famhub_app/features/traceability/presentation/pages/traceability_page.dart';
import 'package:famhub_app/features/carbon_credit/presentation/pages/carbon_credit_page.dart';
import 'package:famhub_app/features/knowledge_link/presentation/pages/knowledge_link_page.dart';
import 'package:famhub_app/features/agribusiness/presentation/pages/agribusiness_page.dart';
import 'package:famhub_app/features/opportunities/presentation/pages/opportunities_page.dart';
import 'package:famhub_app/features/extension_services/presentation/pages/extension_services_page.dart';
import 'package:famhub_app/features/agri_connect/presentation/pages/agri_connect_page.dart';
import 'package:famhub_app/features/agri_tech_lab/presentation/pages/agri_tech_lab_page.dart';
import 'package:famhub_app/features/refferal_hub/presentation/pages/referral_hub_page.dart';
import 'package:famhub_app/features/profile/presentation/pages/profile_page.dart';
import 'package:famhub_app/features/profile/presentation/pages/settings_page.dart';
import 'package:famhub_app/features/admin_console/presentation/pages/admin_dashboard_page.dart';
import 'package:famhub_app/features/guest/guest_homepage.dart';

// ── Enterprise Phase: System Pages ──
import 'package:famhub_app/features/home/presentation/pages/home_page.dart';
import 'package:famhub_app/features/search/presentation/pages/global_search_page.dart';
import 'package:famhub_app/features/notifications/presentation/pages/notification_center_page.dart';
import 'package:famhub_app/features/settings/presentation/pages/runtime_settings_page.dart';
import 'package:famhub_app/features/reports/presentation/pages/reports_center_page.dart';
import 'package:famhub_app/features/ai_assistant/presentation/pages/ai_assistant_page.dart';

/// ============================================================
/// APP ROUTER (SINGLE ROUTING AUTHORITY)
/// ============================================================
///
/// 🧠 ARCHITECTURAL ROLE:
///   core/router/app_router.dart = GoRouter CONFIGURATION ONLY
///   system/registry/route_registry.dart = WHAT routes exist
///   system/registry/module_registry.dart = WHAT modules exist
///
/// ✅ Rules:
///   - EVERY module entryRoute MUST have a corresponding GoRoute here
///   - Route paths come from ModuleRegistry definitions
///   - Named routes from RouteRegistry
///   - NO hardcoded module metadata in route UI
///
/// ❌ Forbidden:
///   - Routes defined outside this file
///   - Feature-level router ownership
/// ============================================================
class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: AppRoutes.root,

      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return UnifiedAppShellV2(child: child);
          },

          routes: [
            GoRoute(
              path: AppRoutes.root,
              name: AppRoutes.rootName,
              builder: (context, state) {
                return const UnifiedDashboardHost();
              },
            ),
            GoRoute(
              path: AppRoutes.farm,
              name: AppRoutes.farmName,
                            builder: (context, state) {
                return const farm.FarmManagementPage();
              },
            ),
            GoRoute(
              path: AppRoutes.marketplace,
              name: AppRoutes.marketplaceName,
              builder: (context, state) {
                return const MarketplacePage();
              },
            ),
            GoRoute(
              path: AppRoutes.analytics,
              name: AppRoutes.analyticsName,
              builder: (context, state) {
                return const AnalyticsPage();
              },
            ),
            GoRoute(
              path: AppRoutes.financing,
              name: AppRoutes.financingName,
              builder: (context, state) {
                return const FinancingPage();
              },
            ),
            GoRoute(
              path: AppRoutes.logistics,
              name: AppRoutes.logisticsName,
              builder: (context, state) {
                return const LogisticsPage();
              },
            ),
            GoRoute(
              path: AppRoutes.traceability,
              name: AppRoutes.traceabilityName,
              builder: (context, state) {
                return const TraceabilityPage();
              },
            ),
            GoRoute(
              path: AppRoutes.carbonCredit,
              name: AppRoutes.carbonCreditName,
              builder: (context, state) {
                return const CarbonCreditPage();
              },
            ),
            GoRoute(
              path: AppRoutes.knowledge,
              name: AppRoutes.knowledgeName,
              builder: (context, state) {
                return const KnowledgeLinkPage();
              },
            ),
            GoRoute(
              path: AppRoutes.agribusiness,
              name: AppRoutes.agribusinessName,
              builder: (context, state) {
                return const AgribusinessPage();
              },
            ),
            GoRoute(
              path: AppRoutes.opportunities,
              name: AppRoutes.opportunitiesName,
              builder: (context, state) {
                return const OpportunitiesPage();
              },
            ),
            GoRoute(
              path: AppRoutes.extension,
              name: AppRoutes.extensionName,
              builder: (context, state) {
                return const ExtensionServicesPage();
              },
            ),
            GoRoute(
              path: AppRoutes.connect,
              name: AppRoutes.connectName,
              builder: (context, state) {
                return const AgriConnectPage();
              },
            ),
            GoRoute(
              path: AppRoutes.techLab,
              name: AppRoutes.techLabName,
              builder: (context, state) {
                return const AgriTechLabPage();
              },
            ),
            GoRoute(
              path: AppRoutes.referrals,
              name: AppRoutes.referralsName,
              builder: (context, state) {
                return const ReferralHubPage();
              },
            ),
            GoRoute(
              path: AppRoutes.profile,
              name: AppRoutes.profileName,
              builder: (context, state) {
                return const ProfilePage();
              },
            ),
            GoRoute(
              path: AppRoutes.settings,
              name: AppRoutes.settingsName,
              builder: (context, state) {
                return const SettingsPage();
              },
            ),
            GoRoute(
              path: AppRoutes.admin,
              name: AppRoutes.adminName,
              builder: (context, state) {
                return const AdminDashboardPage();
              },
            ),
                        GoRoute(
              path: AppRoutes.home,
              name: AppRoutes.homeName,
              builder: (context, state) {
                return const HomePage();
              },
            ),
            GoRoute(
              path: AppRoutes.search,
              name: AppRoutes.searchName,
              builder: (context, state) {
                return const GlobalSearchPage();
              },
            ),
            GoRoute(
              path: AppRoutes.notifications,
              name: AppRoutes.notificationsName,
              builder: (context, state) {
                return const NotificationCenterPage();
              },
            ),
            GoRoute(
              path: AppRoutes.reports,
              name: AppRoutes.reportsName,
              builder: (context, state) {
                return const ReportsCenterPage();
              },
            ),
            GoRoute(
              path: AppRoutes.runtimeSettings,
              name: AppRoutes.runtimeSettingsName,
              builder: (context, state) {
                return const RuntimeSettingsPage();
              },
            ),
            GoRoute(
              path: AppRoutes.aiAssistant,
              name: AppRoutes.aiAssistantName,
              builder: (context, state) {
                return const AIAssistantPage();
              },
            ),
            GoRoute(
              path: AppRoutes.guest,
              name: AppRoutes.guestName,
              builder: (context, state) {
                return const GuestHomePage();
              },
            ),
          ],
        ),
      ],

      errorBuilder: (context, state) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: Colors.orange,
                ),
                SizedBox(height: 16),
                Text(
                  "Page Not Found",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "The requested page could not be found.\nPlease check the URL and try again.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}