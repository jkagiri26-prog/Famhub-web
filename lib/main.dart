import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart'; // Visitor homepage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://erbxiqdfjmqnoeyjupru.supabase.co', // Replace with your Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVyYnhpcWRmam1xbm9leWp1cHJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1MjA4NzcsImV4cCI6MjA4MzA5Njg3N30.by_gz8RbQFlK_WI_QDo1w_W1dgXHZKsO1ZNKxFYg3Xo', // Replace with your anon key
  );

  runApp(SandboxApp());
}

class SandboxApp extends StatelessWidget {
  const SandboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sandbox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.green[700],
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.green[300]),
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[700],
          elevation: 0,
        ),
      ),
      home: VisitorHomePage(), // Opens homepage first
    );
  }
}
