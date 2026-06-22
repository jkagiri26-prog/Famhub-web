import 'package:shared_preferences/shared_preferences.dart';

import 'package:famhub_app/core/services/cache_service.dart';

class AuthService {
  static const String _prefix = 'auth_cache';

  /// Must be called during app/module startup
  static Future<void> init() async {
    await SharedPreferences.getInstance();
  }

  static Future<void> login({
    required String userId,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix:user_id', userId);
    await prefs.setString('$_prefix:role', role);
    await prefs.setBool('$_prefix:logged_in', true);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix:logged_in') ?? false;
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix:user_id') ?? '';
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix:role') ?? 'Farmer';
  }

    static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs.getKeys().where((k) => k.startsWith('$_prefix:'));
    for (final key in keysToRemove) {
      await prefs.remove(key);
  }
  }

  /// Returns the access token for the current session.
  /// In production, this should use Supabase session access token.
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix:access_token');
  }

  /// Set the access token (called by auth flow after login/Supabase session)
  static Future<void> setAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix:access_token', token);
  }
}