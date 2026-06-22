import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/module_activation.dart';
import '../services/activation_cache_service.dart';
import '../services/remote_config_service.dart';

final remoteConfigProvider =
    FutureProvider<List<ModuleActivation>>((ref) async {
  final service = RemoteConfigService();
  final cache = ActivationCacheService();

  try {
    final data = await service.fetch();
    await cache.save(data);
    return data;
  } catch (_) {
    return cache.load(); // offline fallback
  }
});