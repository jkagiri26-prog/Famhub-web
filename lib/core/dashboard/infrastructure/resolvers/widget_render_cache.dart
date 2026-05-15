import 'package:flutter/widgets.dart';

class WidgetRenderCache {
  WidgetRenderCache._();

  static final WidgetRenderCache _instance =
      WidgetRenderCache._();

  factory WidgetRenderCache() => _instance;

  /// widgetKey -> cached builder output
  final Map<String, Widget> _cache = {};

  /// widgetKey -> timestamp
  final Map<String, DateTime> _timestamps = {};

  static const Duration cacheTTL = Duration(minutes: 15);

  /// =========================
  /// GET
  /// =========================
  Widget? get(String widgetKey) {
    if (!_isValid(widgetKey)) {
      _removeInternal(widgetKey);
      return null;
    }

    return _cache[widgetKey];
  }

  /// =========================
  /// SET
  /// =========================
  void set(String widgetKey, Widget widget) {
    _cache[widgetKey] = widget;
    _timestamps[widgetKey] = DateTime.now();
  }

  /// =========================
  /// VALIDITY CHECK
  /// =========================
  bool _isValid(String widgetKey) {
    if (!_cache.containsKey(widgetKey)) return false;

    final timestamp = _timestamps[widgetKey];
    if (timestamp == null) return false;

    final expired =
        DateTime.now().difference(timestamp) > cacheTTL;

    return !expired;
  }

  /// =========================
  /// REMOVE (internal safe)
  /// =========================
  void _removeInternal(String widgetKey) {
    _cache.remove(widgetKey);
    _timestamps.remove(widgetKey);
  }

  void invalidate(String widgetKey) =>
      _removeInternal(widgetKey);

  void clear() {
    _cache.clear();
    _timestamps.clear();
  }

  /// =========================
  /// DEBUG
  /// =========================
  Duration? cacheAge(String widgetKey) {
    final ts = _timestamps[widgetKey];
    if (ts == null) return null;
    return DateTime.now().difference(ts);
  }

  bool contains(String widgetKey) =>
      _cache.containsKey(widgetKey);
}