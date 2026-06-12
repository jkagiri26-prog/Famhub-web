import 'package:shared_preferences/shared_preferences.dart';

class ContextStorageService {
  static const _userKey = 'ctx_user';
  static const _roleKey = 'ctx_role';
  static const _entityKey = 'ctx_entity';
  static const _tierKey = 'ctx_tier';

  Future<void> save({
    required String? userId,
    required String? role,
    required String? entityId,
    String? tier,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId != null) await prefs.setString(_userKey, userId);
    if (role != null) await prefs.setString(_roleKey, role);
    if (entityId != null) await prefs.setString(_entityKey, entityId);
    if (tier != null) await prefs.setString(_tierKey, tier);
  }

  Future<Map<String, String?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_userKey),
      'role': prefs.getString(_roleKey),
      'entityId': prefs.getString(_entityKey),
      'tier': prefs.getString(_tierKey),
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}