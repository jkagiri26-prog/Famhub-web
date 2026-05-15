import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthProvider with ChangeNotifier {
  String? _role;
  bool _isAuthenticated = false;

  String? get role => _role;
  bool get isAuthenticated => _isAuthenticated;

  /// Load initial state from Hive. 
  /// Since ModuleRegistry.initHive() is called in main(), 
  /// we assume the box is already open.
  Future<void> loadAuth() async {
    final box = Hive.box('auth_cache');
    _role = box.get('role');
    _isAuthenticated = _role != null && _role != 'Guest';
    notifyListeners();
  }

  /// Updates the role and notifies all listeners (e.g., MainShell)
  Future<void> login(String role) async {
    final box = Hive.box('auth_cache');
    await box.put('role', role);
    await box.put('logged_in', true);
    
    _role = role;
    _isAuthenticated = true;
    notifyListeners();
  }

  /// Clears local storage and resets the app state
  Future<void> logout() async {
    final box = Hive.box('auth_cache');
    await box.clear();
    
    _role = 'Guest';
    _isAuthenticated = false;
    notifyListeners();
  }
}