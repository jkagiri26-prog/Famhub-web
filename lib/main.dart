import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

// FOUNDATION IMPORTS
import 'services_page.dart';
import 'carbon_provider.dart';
import 'auth_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FamHubService.initHive(); 
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

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
        scaffoldBackgroundColor: const Color(0xFFEDF0F3), 
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
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

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  void _checkInitialAuth() {
    final savedRole = FamHubService.getLocalData('auth_cache', 'role');
    if (savedRole != null) setState(() => _isAuthenticated = true);
  }

  void _showNotificationPanel(BuildContext context, Color color) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Notifications", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            ListTile(leading: Icon(Icons.info, color: color), title: const Text("New market prices updated")),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeGreen = Theme.of(context).colorScheme.primary;
    final String role = FamHubService.getLocalData('auth_cache', 'role', defaultValue: 'Farmer');
    final List<ModuleRegistry> visibleModules = FamHubService.getModulesForRole(role);

    if (!_isAuthenticated) {
      return AuthPage(role: "Farmer", onAuthComplete: () {
        FamHubService.saveLocalData('auth_cache', 'role', 'Farmer');
        setState(() => _isAuthenticated = true);
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildEliteDrawer(visibleModules, themeGreen),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text("FAMHUB", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)),
        actions: [
          IconButton(
            icon: const Badge(label: Text("3"), child: Icon(Icons.notifications_none_rounded)),
            onPressed: () => _showNotificationPanel(context, themeGreen),
          ),
          _buildWallet(themeGreen),
          const SizedBox(width: 12),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: visibleModules.map((m) => m.page).toList(),
      ),
      bottomNavigationBar: _buildBottomNav(visibleModules, themeGreen),
    );
  }

  Widget _buildWallet(Color color) {
    return GestureDetector(
      onTap: () => setState(() => _isBalanceHidden = !_isBalanceHidden),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(_isBalanceHidden ? "****" : "KSH 12,500", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11)),
      ),
    );
  }

  Widget _buildBottomNav(List<ModuleRegistry> modules, Color color) {
    final bottomModules = modules.take(4).toList();
    return BottomNavigationBar(
      currentIndex: _currentIndex < 4 ? _currentIndex : 0,
      onTap: (i) => i == 4 ? _scaffoldKey.currentState?.openDrawer() : setState(() => _currentIndex = i),
      selectedItemColor: color,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: [
        ...bottomModules.map((m) => BottomNavigationBarItem(icon: Icon(m.icon), label: m.label)),
        const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: "More"),
      ],
    );
  }

  Widget _buildEliteDrawer(List<ModuleRegistry> modules, Color color) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(child: Center(child: Text("FAMHUB MENU", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)))),
          Expanded(
            child: ListView.builder(
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final m = modules[index];
                return ListTile(
                  leading: Icon(m.icon, color: _currentIndex == index ? color : Colors.black54),
                  title: Text(m.label, style: const TextStyle(fontWeight: FontWeight.bold)), // Bold List Names
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
            title: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await Hive.box('auth_cache').clear();
              setState(() => _isAuthenticated = false);
            },
          ),
        ],
      ),
    );
  }
}