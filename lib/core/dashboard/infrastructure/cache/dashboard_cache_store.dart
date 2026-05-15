import '../../domain/models/dashboard_descriptor.dart';

class DashboardCacheStore {
  DashboardCacheStore._();

  static final DashboardCacheStore _instance =
      DashboardCacheStore._();

  factory DashboardCacheStore() => _instance;

  /// moduleKey -> descriptors
  final Map<String, List<DashboardDescriptor>> _descriptorCache = {};

  /// moduleKey -> cache timestamp
  final Map<String, DateTime> _timestamps = {};

  /// moduleKey -> cache version (for future sync conflict resolution)
  final Map<String, int> _versions = {};

  static const Duration cacheTTL = Duration(minutes: 10);

  /// =========================
  /// WRITE CACHE
  /// =========================
  void set(
    String moduleKey,
    List<DashboardDescriptor> descriptors,
  ) {
    _descriptorCache[moduleKey] =
        List.unmodifiable(descriptors); // 🔥 IMMUTABLE SNAPSHOT

    _timestamps[moduleKey] = DateTime.now();

    _versions[moduleKey] =
        (_versions[moduleKey] ?? 0) + 1;
  }

  /// =========================
  /// READ CACHE
  /// =========================
  List<DashboardDescriptor>? get(String moduleKey) {
    if (!hasValidCache(moduleKey)) {
      remove(moduleKey);
      return null;
    }

    final data = _descriptorCache[moduleKey];

    return data == null ? null : List.unmodifiable(data);
  }

  /// =========================
  /// VALIDITY CHECK
  /// =========================
  bool hasValidCache(String moduleKey) {
    final timestamp = _timestamps[moduleKey];
    if (timestamp == null) return false;

    final expired =
        DateTime.now().difference(timestamp) > cacheTTL;

    return _descriptorCache.containsKey(moduleKey) &&
        !expired;
  }

  /// =========================
  /// CACHE VERSION (future diff sync support)
  /// =========================
  int version(String moduleKey) {
    return _versions[moduleKey] ?? 0;
  }

  /// =========================
  /// DELETE / INVALIDATE
  /// =========================
  void remove(String moduleKey) {
    _descriptorCache.remove(moduleKey);
    _timestamps.remove(moduleKey);
    _versions.remove(moduleKey);
  }

  void invalidate(String moduleKey) => remove(moduleKey);

  void clearAll() {
    _descriptorCache.clear();
    _timestamps.clear();
    _versions.clear();
  }

  /// =========================
  /// DEBUG HELPERS
  /// =========================
  Duration? cacheAge(String moduleKey) {
    final timestamp = _timestamps[moduleKey];
    if (timestamp == null) return null;

    return DateTime.now().difference(timestamp);
  }

  bool contains(String moduleKey) =>
      _descriptorCache.containsKey(moduleKey);
}