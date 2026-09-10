import 'package:shared_preferences/shared_preferences.dart';

class ContextStorageService {
  static const _userKey = 'ctx_user';
  static const _profileKey = 'ctx_profile';
  static const _roleKey = 'ctx_role';
  static const _roleIdKey = 'ctx_role_id';
  static const _entityKey = 'ctx_entity';
  static const _businessProfileKey = 'ctx_business_profile';
  static const _tierKey = 'ctx_tier';

  Future<void> save({
    required String? userId,
    required String? profileId,
    required String? role,
    required String? roleId,
    required String? entityId,
    String? businessProfileId,
    String? tier,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId != null) await prefs.setString(_userKey, userId);
    if (profileId != null) await prefs.setString(_profileKey, profileId);
    if (role != null) await prefs.setString(_roleKey, role);
    if (roleId != null) await prefs.setString(_roleIdKey, roleId);
    if (entityId != null) await prefs.setString(_entityKey, entityId);
    if (businessProfileId != null) {
      await prefs.setString(_businessProfileKey, businessProfileId);
    }
    if (tier != null) await prefs.setString(_tierKey, tier);
  }

  Future<Map<String, String?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_userKey),
      'profileId': prefs.getString(_profileKey),
      'role': prefs.getString(_roleKey),
      'roleId': prefs.getString(_roleIdKey),
      'entityId': prefs.getString(_entityKey),
      'businessProfileId': prefs.getString(_businessProfileKey),
      'tier': prefs.getString(_tierKey),
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
