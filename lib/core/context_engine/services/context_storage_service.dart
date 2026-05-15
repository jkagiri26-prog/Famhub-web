import 'package:shared_preferences/shared_preferences.dart';

class ContextStorageService {
  static const _userKey = 'ctx_user';
  static const _roleKey = 'ctx_role';
  static const _entityKey = 'ctx_entity';

  Future<void> save({
    required String? userId,
    required String? role,
    required String? entityId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId != null) await prefs.setString(_userKey, userId);
    if (role != null) await prefs.setString(_roleKey, role);
    if (entityId != null) await prefs.setString(_entityKey, entityId);
  }

  Future<Map<String, String?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_userKey),
      'role': prefs.getString(_roleKey),
      'entityId': prefs.getString(_entityKey),
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}