import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services_page.dart';
import 'carbon_provider.dart';
import 'auth_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FamHubService.initHive(); 
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CarbonProvider())],
      child: const FamHubApp(),
    ),
  );
}

class FamHubApp extends StatelessWidget {
  const FamHubApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // NEW BACKGROUND THEME
        scaffoldBackgroundColor: const Color(0xFFEDF0F3), 
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
          surface: const Color(0xFFEDF0F3),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isBalanceHidden = true;
  bool _isAuthenticated = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Color> _mutedPalette = [
    const Color(0xFF78909C), const Color(0xFF8D6E63), const Color(0xFF667C66),
    const Color(0xFF7986CB), const Color(0xFF90A4AE), const Color(0xFFA1887F),
  ];

  Color _getIconColor(int index, bool isSelected, Color primary) {
    if (isSelected) return primary;
    return _mutedPalette[index % _mutedPalette.length];
  }

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  void _checkInitialAuth() {
    final savedRole = FamHubService.getLocalData('auth_cache', 'role');
    if (savedRole != null) setState(() => _isAuthenticated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return AuthPage(role: "Farmer", onAuthComplete: () {
        FamHubService.saveLocalData('auth_cache', 'role', 'Farmer');
        setState(() => _isAuthenticated = true);
      });
    }

    final String role = FamHubService.getLocalData('auth_cache', 'role', defaultValue: 'Farmer');
    final List<ModuleRegistry> visibleModules = FamHubService.getModulesForRole(role, []);
    final themeGreen = Theme.of(context).colorScheme.primary;
    final bool isLargeScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isLargeScreen ? null : _buildDrawer(visibleModules, themeGreen, role),
      body: Row(
        children: [
          if (isLargeScreen) 
            Container(
              width: 260,
              decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.grey.shade200))),
              child: _buildDrawer(visibleModules, themeGreen, role, isPermanent: true),
            ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(visibleModules[_currentIndex].label, themeGreen, !isLargeScreen),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: visibleModules.map((m) => m.page).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isLargeScreen ? null : _buildBottomNav(visibleModules, themeGreen),
    );
  }

  Widget _buildHeader(String title, Color color, bool showMenu) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.transparent, // Blends with new scaffold background
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (showMenu) IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
              Icon(Icons.eco_rounded, color: color, size: 28),
              const SizedBox(width: 8),
              Text("FAMHUB", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: color, letterSpacing: -1)),
              const Spacer(),
              _buildWallet(color),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 44),
              Text(title.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 1.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWallet(Color color) {
    return GestureDetector(
      onTap: () => setState(() => _isBalanceHidden = !_isBalanceHidden),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white, // Pop white against grey background
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 12, color: color),
            const SizedBox(width: 8),
            Text(_isBalanceHidden ? "****" : "KSH 12,500", style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(List<ModuleRegistry> modules, Color color) {
    final bottomModules = modules.take(4).toList();
    return BottomNavigationBar(
      currentIndex: _currentIndex < 4 ? _currentIndex : 0,
      onTap: (i) => i == 4 ? _scaffoldKey.currentState?.openDrawer() : setState(() => _currentIndex = i),
      selectedItemColor: color,
      backgroundColor: Colors.white,
      unselectedItemColor: Colors.grey.shade400,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: [
        ...bottomModules.asMap().entries.map((e) => BottomNavigationBarItem(
          icon: Icon(e.value.icon, color: _getIconColor(e.key, _currentIndex == e.key, color)),
          label: e.value.label,
        )),
        const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: "More"),
      ],
    );
  }

  Widget _buildDrawer(List<ModuleRegistry> modules, Color color, String role, {bool isPermanent = false}) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isPermanent) DrawerHeader(child: Center(child: Text("FAMHUB MENU", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24)))),
          if (isPermanent) const Padding(
            padding: EdgeInsets.fromLTRB(24, 60, 24, 20),
            child: Text("NAVIGATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final m = modules[index];
                final isSelected = _currentIndex == index;
                final iconColor = _getIconColor(index, isSelected, color);
                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(m.icon, color: iconColor, size: 20),
                    title: Text(m.label, style: TextStyle(fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500, color: isSelected ? color : Colors.black54, fontSize: 13)),
                    onTap: () {
                      setState(() => _currentIndex = index);
                      if (!isPermanent) Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(indent: 20, endIndent: 20),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
            title: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            onTap: () async {
              await Hive.box('auth_cache').clear();
              setState(() => _isAuthenticated = false);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}