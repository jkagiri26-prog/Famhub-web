// TEST CHANGE - SHOULD SEE FAMHUB
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://https://erbxiqdfjmqnoeyjupru.supabase.co', // Replace with your Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVyYnhpcWRmam1xbm9leWp1cHJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1MjA4NzcsImV4cCI6MjA4MzA5Njg3N30.by_gz8RbQFlK_WI_QDo1w_W1dgXHZKsO1ZNKxFYg3Xo',                // Replace with your anon key
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FamHub')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            final client = Supabase.instance.client;
            final user = client.auth.currentUser;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  user != null
                      ? 'Logged in as ${user.email}'
                      : 'No user logged in',
                ),
              ),
            );
          },
          child: const Text('Check Supabase User'),
        ),
      ),
    );
  }
}
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session == null) {
          return AuthPage();
        } else {
          return HomePage();
        }
      },
    );
  }
}
