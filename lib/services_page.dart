import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// --- FEATURE PAGE IMPORTS ---
import 'home_page.dart';
import 'farmer_dashboard_page.dart'; 
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
import 'referral_hub.dart'; 
import 'carbon_credit_page.dart'; // ADDED: Carbon Credit Module

/// FAMHUB: Module Development & Submission Protocol
/// Registry & Service Orchestrator
/// Version: 2026-02-09 | Deployment Sync: UUID v7 Architecture Aligned

class ModuleRegistry {
  final String label;
  final String boxName;
  final Widget page;
  final IconData icon;
  final bool preserveState;
  final String? description;

  const ModuleRegistry({
    required this.label,
    required this.boxName,
    required this.page,
    required this.icon,
    this.preserveState = false,
    this.description,
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
          label: 'Carbon Credits', // NEW: Carbon Credit Module
          boxName: 'carbon_cache',
          page: CarbonCreditPage(),
          icon: Icons.diversity_3_rounded,
          description: 'Offset & Community Support',
          preserveState: true,
        ),
        const ModuleRegistry(
          label: 'Referral Hub',
          boxName: 'referral_cache',
          page: ReferralHubPage(),
          icon: Icons.stars_rounded,
          description: 'Refer & Earn: Invite friends and get rewarded.',
          preserveState: true,
        ),
        const ModuleRegistry(
          label: 'Profile', 
          boxName: 'profile_cache',
          page: ProfilePage(),
          icon: Icons.account_circle_rounded,
          preserveState: true,
        ),
        const ModuleRegistry(
          label: 'Traceability',
          boxName: 'traceability_cache',
          page: TraceabilityPage(),
          icon: Icons.enhanced_encryption_rounded,
          preserveState: true,
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
          page: SocialSpacePage(), 
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
    try {
      await Hive.initFlutter();
      for (var module in famHubModules) {
        if (!Hive.isBoxOpen(module.boxName)) {
          await Hive.openBox(module.boxName);
        }
      }
    } catch (e) {
      debugPrint("FAMHUB_HIVE_INIT_FAILED: $e");
    }
  }
}

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = FamHubService.famHubModules;
    
    return Container(
      width: double.infinity, // FAMHUB Root Constraint
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Explore Services',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                return _buildModuleCard(context, module);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, ModuleRegistry module) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => module.page),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(module.icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              module.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (module.description != null)
               Padding(
                 padding: const EdgeInsets.only(top: 4.0),
                 child: Text(
                   module.label == 'Referral Hub' ? "Earn Rewards" : "Village Support",
                   style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.secondary),
                 ),
               ),
          ],
        ),
      ),
    );
  }
}
