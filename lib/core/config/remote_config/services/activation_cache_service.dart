import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/module_activation.dart';

class ActivationCacheService {
  static const _key = 'module_activation';

  Future<void> save(List<ModuleActivation> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final data = configs.map((e) => jsonEncode({
      'moduleName': e.moduleName,
      'isEnabled': e.isEnabled,
      'allowedRoles': e.allowedRoles,
      'regions': e.regions,
      'rollout': e.rolloutPercentage,
    })).toList();

    await prefs.setStringList(_key, data);
  }

  Future<List<ModuleActivation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    return raw.map((e) {
      final j = jsonDecode(e);
      return ModuleActivation(
        moduleName: j['moduleName'],
        isEnabled: j['isEnabled'],
        allowedRoles: List<String>.from(j['allowedRoles']),
        regions: j['regions'] != null
            ? List<String>.from(j['regions'])
            : null,
        rolloutPercentage: j['rollout'],
      );
    }).toList();
  }
}