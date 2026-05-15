import 'package:flutter/widgets.dart';

enum DeviceType {
  mobile,
  tablet,
  desktop,
}

class DeviceLayoutService {
  /// Cached last computed width (per build cycle safety)
  static double? _lastWidth;
  static DeviceType? _lastType;

  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    /// -----------------------------------------
    /// FAST PATH (avoid recomputation)
    /// -----------------------------------------
    if (_lastWidth == width && _lastType != null) {
      return _lastType!;
    }

    _lastWidth = width;

    _lastType = _compute(width);

    return _lastType!;
  }

  /// -----------------------------------------
  /// CORE LOGIC (isolated for future scaling)
  /// -----------------------------------------
  static DeviceType _compute(double width) {
    if (width >= 1100) return DeviceType.desktop;
    if (width >= 600) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  /// -----------------------------------------
  /// OPTIONAL: EXPLICIT API (useful later)
  /// -----------------------------------------
  static bool isMobile(BuildContext context) =>
      getDeviceType(context) == DeviceType.mobile;

  static bool isTablet(BuildContext context) =>
      getDeviceType(context) == DeviceType.tablet;

  static bool isDesktop(BuildContext context) =>
      getDeviceType(context) == DeviceType.desktop;
}