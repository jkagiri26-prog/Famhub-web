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