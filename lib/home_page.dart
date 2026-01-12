import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;

  String? userEmail;
  String? userPhone;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      userEmail = user.email;
      userPhone = user.phone;
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    // Redirect back to AuthPage
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FamHub Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (userEmail != null)
              Text('Logged in as Email: $userEmail'),
            if (userPhone != null)
              Text('Logged in as Phone: $userPhone'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _signOut,
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}