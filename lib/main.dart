import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://erbxiqdfjmqnoeyjupru.supabase.co', // Replace with your Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVyYnhpcWRmam1xbm9leWp1cHJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1MjA4NzcsImV4cCI6MjA4MzA5Njg3N30.by_gz8RbQFlK_WI_QDo1w_W1dgXHZKsO1ZNKxFYg3Xo', // Replace with your anon key
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}

/// Decides whether to show AuthPage or HomePage
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session == null) {
          return const AuthPage(); // OTP login page
        } else {
          return const HomePage(); // After login
        }
      },
    );
  }
}
