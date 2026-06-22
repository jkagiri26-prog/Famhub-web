import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:famhub_app/core/modules/domain/models/module_activation.dart';

/// =======================================================
/// FAMHUB ACTIVATION CACHE SERVICE
/// =======================================================
///
/// RESPONSIBILITY:
/// - Cache remote module activation state locally
/// - Improve startup performance
/// - Reduce unnecessary network fetches
/// - Provide offline fallback support
///
/// RULES:
/// - NO business logic
/// - NO feature gating decisions
/// - NO module authority
/// - Backend remains authoritative
///
/// =======================================================

class CacheService {
  CacheService({
    SharedPreferences? sharedPreferences,
  }) : _prefsFuture = sharedPreferences != null
            ? Future.value(sharedPreferences)
            : SharedPreferences.getInstance();

  static const String _cacheKey = 'famhub_module_activation_cache';

  final Future<SharedPreferences> _prefsFuture;

  /// =======================================================
  /// SAVE ACTIVATIONS
  /// =======================================================

  Future<void> saveActivations(
    List<ModuleActivation> activations,
  ) async {
    final prefs = await _prefsFuture;
    final encoded = activations.map((a) => a.toJson()).toList();
    final jsonString = jsonEncode(encoded);
    await prefs.setString(_cacheKey, jsonString);
  }

  /// =======================================================
  /// LOAD ACTIVATIONS
  /// =======================================================

  Future<List<ModuleActivation>> loadActivations() async {
    try {
      final prefs = await _prefsFuture;
      final cachedString = prefs.getString(_cacheKey);
      if (cachedString == null || cachedString.isEmpty) return const [];
      final decoded = jsonDecode(cachedString);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ModuleActivation.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// =======================================================
  /// CLEAR CACHE
  /// =======================================================

  Future<void> clearCache() async {
    final prefs = await _prefsFuture;
    await prefs.remove(_cacheKey);
  }

  /// =======================================================
  /// CACHE EXISTS
  /// =======================================================

  Future<bool> hasCache() async {
    final prefs = await _prefsFuture;
    return prefs.containsKey(_cacheKey);
  }
}
