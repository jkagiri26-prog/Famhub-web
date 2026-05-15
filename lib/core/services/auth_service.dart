import 'cache_service.dart';

class AuthService {
  static const String _box = 'auth_cache';

  /// Must be called during app/module startup
  static Future<void> init() async {
    await CacheService.openBox(_box);
  }

  static Future<void> login({
    required String userId,
    required String role,
  }) async {
    await CacheService.put(_box, 'user_id', userId);
    await CacheService.put(_box, 'role', role);
    await CacheService.put(_box, 'logged_in', true);
  }

  static bool isLoggedIn() {
    return CacheService.get<bool>(_box, 'logged_in', defaultValue: false) ?? false;
  }

  static String getUserId() {
    return CacheService.get<String>(_box, 'user_id', defaultValue: '') ?? '';
  }

  static String getRole() {
    // Defaulting to 'Farmer' per your business logic
    return CacheService.get<String>(_box, 'role', defaultValue: 'Farmer') ?? 'Farmer';
  }

  static Future<void> logout() async {
    await CacheService.clear(_box);
  }
}