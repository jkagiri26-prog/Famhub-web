/// ============================================================
/// DEPRECATED - Legacy Shell (Do Not Use)
/// ============================================================
///
/// STATUS: LEGACY / DEPRECATED
///
/// This file contains the OLD MainShell which was the shell
/// before the runtime architecture was built. It contains:
///   - Hardcoded Farm and Marketplace modules
///   - Direct imports of feature pages
///   - Non-responsive layout
///   - No runtime governance
///
/// DO NOT IMPORT OR USE THIS FILE.
///
/// USE INSTEAD:
///   - UnifiedAppShell in core/shell/unified_app_shell.dart
///   - DesktopShell in core/shell/desktop_shell.dart
///   - TabletShell in core/shell/tablet_shell.dart
///   - MobileShell in core/shell/mobile_shell.dart
///
/// The runtime architecture (RuntimeCompositionEngine +
/// RuntimeContributionEngine + Context Engine) has fully
/// replaced this legacy shell.
///
/// This file is kept only for reference and will be removed
/// in a future cleanup phase.
///
/// Last updated: Stabilization Phase A
/// ============================================================
library;

// ignore_for_file: unused_import, unused_element

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:famhub_app/core/providers/auth_provider.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/farm_dashboard_page.dart' as farm;
import 'package:famhub_app/features/marketplace/presentation/pages/marketplace_page.dart';

/// Represents a runtime module with UI capabilities for the shell.
/// DEPRECATED - This class is part of the legacy shell
class ShellModule {
  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  const ShellModule({
    required this.title,
    required this.icon,
    required this.builder,
  });
}

/// DEPRECATED - Use UnifiedAppShell instead
class MainShell extends StatefulWidget {
  final String role;
  const MainShell({super.key, required this.role});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  /// Resolves available modules based on user role.
  List<ShellModule> _getModulesForRole(String role) {
    return [
      const ShellModule(
        title: 'Farm',
        icon: Icons.agriculture,
        builder: _buildFarmPage,
      ),
      const ShellModule(
        title: 'Marketplace',
        icon: Icons.store,
        builder: _buildMarketplacePage,
      ),
    ];
  }

    static Widget _buildFarmPage(BuildContext context) {
    return const farm.FarmManagementPage();
  }

  static Widget _buildMarketplacePage(BuildContext context) {
    return const MarketplacePage();
  }

  @override
  Widget build(BuildContext context) {
    final visibleModules = _getModulesForRole(widget.role);

    if (visibleModules.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No modules available for your role.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("FAMHUB", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      drawer: _buildDrawer(visibleModules),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: visibleModules.map((m) => m.builder(context)).toList(),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex < 4 ? _currentIndex : 4,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 4) {
            Scaffold.of(context).openDrawer();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: [
          ...visibleModules.take(4).map((m) =>
              BottomNavigationBarItem(icon: Icon(m.icon), label: m.title)),
          const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded), label: "More"),
        ],
      ),
    );
  }

  Widget _buildDrawer(List modules) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person)),
            accountName: Text("Role: ${widget.role}", style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text("Verified FAMHUB User"),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                return ListTile(
                  leading: Icon(module.icon,
                      color: _currentIndex == index
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black54),
                  title: Text(module.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  selected: _currentIndex == index,
                  onTap: () {
                    setState(() => _currentIndex = index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              context.read<AuthProvider>().logout();
              Navigator.pushReplacementNamed(context, '/auth');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
