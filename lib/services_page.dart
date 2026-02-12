import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// --- ALL FEATURE PAGE IMPORTS ---
import 'auth_page.dart';
import 'home_page.dart';
import 'farmer_dashboard_page.dart'; 
import 'trader_dashboard_page.dart';      
import 'stakeholder_dashboard_page.dart'; 
import 'admin_dashboard_page.dart';       
import 'marketplace_page.dart'; 
import 'social_space_page.dart'; 
import 'analytics_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'knowledge_link_page.dart';
import 'logistics_page.dart';
import 'agribusiness_page.dart';
import 'extension_services_page.dart';
import 'financing_page.dart';
import 'opportunities_page.dart';
import 'tech_corner_page.dart';
import 'traceability_page.dart';
import 'referral_hub_page.dart'; 
import 'carbon_credit_page.dart';

class ModuleRegistry {
  final String label;
  final String boxName;
  final Widget page;
  final IconData icon;
  final List<String> allowedRoles;

  const ModuleRegistry({
    required this.label,
    required this.boxName,
    required this.page,
    required this.icon,
    this.allowedRoles = const ['All'],
  });
}

class FamHubService {
  static List<ModuleRegistry> get famHubModules => [
    const ModuleRegistry(label: 'Home', boxName: 'home_cache', page: HomePage(), icon: Icons.home_rounded),
    const ModuleRegistry(label: 'Farmer Dash', boxName: 'f_dash', page: FarmerDashboardPage(), icon: Icons.dashboard_rounded, allowedRoles: ['Farmer']),
    const ModuleRegistry(label: 'Trader Dash', boxName: 't_dash', page: TraderDashboardPage(), icon: Icons.analytics_rounded, allowedRoles: ['Trader']),
    const ModuleRegistry(label: 'Admin Panel', boxName: 'a_dash', page: AdminDashboardPage(), icon: Icons.admin_panel_settings_rounded, allowedRoles: ['Admin']),
    const ModuleRegistry(label: 'Marketplace', boxName: 'mkt_cache', page: MarketplacePage(), icon: Icons.storefront_rounded),
    const ModuleRegistry(label: 'Social', boxName: 'soc_cache', page: SocialSpacePage(), icon: Icons.groups_rounded),
    const ModuleRegistry(label: 'Carbon Credits', boxName: 'carb_cache', page: CarbonCreditPage(), icon: Icons.eco_rounded),
    const ModuleRegistry(label: 'Logistics', boxName: 'log_cache', page: LogisticsPage(), icon: Icons.local_shipping_rounded),
    const ModuleRegistry(label: 'Financing', boxName: 'fin_cache', page: FinancingPage(), icon: Icons.payments_rounded),
    const ModuleRegistry(label: 'Agribusiness', boxName: 'agri_cache', page: AgribusinessPage(), icon: Icons.business_center_rounded),
    const ModuleRegistry(label: 'Extension', boxName: 'ext_cache', page: ExtensionServicesPage(), icon: Icons.psychology_rounded),
    const ModuleRegistry(label: 'Knowledge', boxName: 'know_cache', page: KnowledgeLinkPage(), icon: Icons.menu_book_rounded),
    const ModuleRegistry(label: 'Traceability', boxName: 'trace_cache', page: TraceabilityPage(), icon: Icons.qr_code_scanner_rounded),
    const ModuleRegistry(label: 'Opportunities', boxName: 'opp_cache', page: OpportunitiesPage(), icon: Icons.lightbulb_rounded),
    // FIXED: Added required userRole parameter
    const ModuleRegistry(label: 'Tech Corner', boxName: 'tech_cache', page: TechCornerPage(userRole: 'Farmer'), icon: Icons.memory_rounded),
    const ModuleRegistry(label: 'Referral Hub', boxName: 'ref_cache', page: ReferralHubPage(), icon: Icons.share_rounded),
    const ModuleRegistry(label: 'Analytics', boxName: 'ana_cache', page: AnalyticsPage(), icon: Icons.bar_chart_rounded),
    const ModuleRegistry(label: 'Profile', boxName: 'prof_cache', page: ProfilePage(), icon: Icons.person_rounded),
    const ModuleRegistry(label: 'Settings', boxName: 'set_cache', page: SettingsPage(), icon: Icons.settings_rounded),
  ];

  static List<ModuleRegistry> getModulesForRole(String role, List<String> permissions) {
    if (role == 'Admin') return famHubModules;
    return famHubModules.where((m) => m.allowedRoles.contains('All') || m.allowedRoles.contains(role)).toList();
  }

  static Future<void> initHive() async {
    await Hive.initFlutter();
    for (var m in famHubModules) {
      if (!Hive.isBoxOpen(m.boxName)) await Hive.openBox(m.boxName);
    }
    if (!Hive.isBoxOpen('auth_cache')) await Hive.openBox('auth_cache');
  }

  static dynamic getLocalData(String box, String key, {dynamic defaultValue}) =>
      Hive.box(box).get(key, defaultValue: defaultValue);

  static Future<void> saveLocalData(String box, String key, dynamic value) async =>
      await Hive.box(box).put(key, value);
}