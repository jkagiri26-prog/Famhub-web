import 'package:flutter/material.dart';
import 'services_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FamHubService.initHive();
  runApp(const FamHubApp());
}

class FamHubApp extends StatelessWidget {
  const FamHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final modules = FamHubService.famHubModules;
    final primaryGreen = Theme.of(context).colorScheme.primary;

    return Scaffold(
      key: _scaffoldKey,
      // The Drawer handles the full list of 14 modules
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: primaryGreen),
              child: const Center(
                child: Text("FAMHUB SERVICES", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: modules.length,
                itemBuilder: (context, i) {
                  return ListTile(
                    leading: Icon(modules[i].icon, color: _currentIndex == i ? primaryGreen : Colors.grey),
                    title: Text(modules[i].label, 
                      style: TextStyle(
                        fontWeight: _currentIndex == i ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14
                      )
                    ),
                    selected: _currentIndex == i,
                    onTap: () {
                      setState(() => _currentIndex = i);
                      Navigator.pop(context); // Close drawer
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: modules.map((m) => m.page).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex < 4 ? _currentIndex : 4, // Clamp to "More" if index is high
        onTap: (index) {
          if (index == 4) {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: [
          ...modules.take(4).map((m) => BottomNavigationBarItem(
            icon: Icon(m.icon),
            label: m.label,
          )),
          const BottomNavigationBarItem(
            icon: Icon(Icons.menu_rounded),
            label: "More",
          ),
        ],
      ),
    );
  }
}