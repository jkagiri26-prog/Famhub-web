import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// --- ALL 14 FEATURE PAGE IMPORTS ---
import 'home_page.dart';
import 'farmer_dashboard_page.dart'; 
import 'marketplace_page.dart'; 
import 'social_space_page.dart'; 
import 'analytics_page.dart';
import 'settings_page.dart';
import 'otp_page.dart';
import 'knowledge_link_page.dart';
import 'logistics_page.dart';
import 'agribusiness_page.dart';
import 'extension_services_page.dart';
import 'financing_page.dart';
import 'opportunities_page.dart';
import 'tech_corner_page.dart';

class ModuleRegistry {
  final String label;
  final String boxName;
  final Widget page;
  final IconData icon;
  final bool preserveState;

  const ModuleRegistry({
    required this.label,
    required this.boxName,
    required this.page,
    required this.icon,
    this.preserveState = false,
  });
}

class FamHubService {
  static List<ModuleRegistry> get famHubModules => [
        const ModuleRegistry(
          label: 'Home',
          boxName: 'home_cache',
          page: HomePage(),
          icon: Icons.home_rounded,
        ),
        const ModuleRegistry(
          label: 'Dashboard',
          boxName: 'farmer_dashboard_cache',
          page: FarmerDashboardPage(),
          icon: Icons.dashboard_rounded,
          preserveState: true,
        ),
        const ModuleRegistry(
          label: 'Marketplace',
          boxName: 'marketplace_cache',
          page: MarketplacePage(), 
          icon: Icons.storefront_rounded,
          preserveState: true,
        ),
        const ModuleRegistry(
          label: 'Social',
          boxName: 'social_cache',
          page: SocialServicesPage(), 
          icon: Icons.groups_rounded,
          preserveState: true,
        ),
        const ModuleRegistry(
          label: 'Analytics',
          boxName: 'analytics_cache',
          page: AnalyticsPage(),
          icon: Icons.bar_chart_rounded,
          preserveState: true,
        ),
        const ModuleRegistry(
          label: 'Logistics',
          boxName: 'logistics_cache',
          page: LogisticsPage(),
          icon: Icons.local_shipping_rounded,
        ),
        const ModuleRegistry(
          label: 'Financing',
          boxName: 'financing_cache',
          page: FinancingPage(),
          icon: Icons.account_balance_wallet_rounded,
        ),
        const ModuleRegistry(
          label: 'Knowledge',
          boxName: 'knowledge_cache',
          page: KnowledgeLinkPage(),
          icon: Icons.auto_stories_rounded,
        ),
        const ModuleRegistry(
          label: 'Extension',
          boxName: 'extension_cache',
          page: ExtensionServicesPage(),
          icon: Icons.psychology_rounded,
        ),
        const ModuleRegistry(
          label: 'Opportunities',
          boxName: 'opps_cache',
          page: OpportunitiesPage(),
          icon: Icons.lightbulb_rounded,
        ),
        const ModuleRegistry(
          label: 'Agribusiness',
          boxName: 'agribiz_cache',
          page: AgribusinessPage(),
          icon: Icons.business_center_rounded,
        ),
        const ModuleRegistry(
          label: 'Tech Corner',
          boxName: 'tech_cache',
          page: TechCornerPage(userRole: 'Farmer'),
          icon: Icons.memory_rounded,
        ),
        const ModuleRegistry(
          label: 'Settings',
          boxName: 'settings_cache',
          page: SettingsPage(),
          icon: Icons.settings_rounded,
        ),
      ];

  static Future<void> initHive() async {
    await Hive.initFlutter();
    for (var module in famHubModules) {
      if (!Hive.isBoxOpen(module.boxName)) {
        await Hive.openBox(module.boxName);
      }
    }
  }
}