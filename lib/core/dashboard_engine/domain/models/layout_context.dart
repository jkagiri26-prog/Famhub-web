import 'package:flutter/foundation.dart';

/// ============================================================
/// LAYOUT CONTEXT (DOMAIN CORE)
/// ============================================================
///
/// Pure runtime context used ONLY for layout resolution.
///
/// It does NOT:
/// - decide layout
/// - contain business logic
/// - access system registry
/// ============================================================

enum LayoutDeviceType {
  mobile,
  tablet,
  desktop,
}

@immutable
class LayoutContext {
  /// Device classification for layout adaptation
  final LayoutDeviceType device;

  /// User role (used for layout resolution only)
  final String? role;

  /// Entity context (farm, organization, workspace, etc.)
  final String? entityId;

  const LayoutContext({
    required this.device,
    this.role,
    this.entityId,
  });

  /// ============================================================
  /// PURE UTILITY (NO BUSINESS LOGIC)
  /// ============================================================

  bool get isMobile => device == LayoutDeviceType.mobile;

  bool get isTablet => device == LayoutDeviceType.tablet;

  bool get isDesktop => device == LayoutDeviceType.desktop;

  /// ============================================================
  /// IMMUTABLE COPY SUPPORT
  /// ============================================================

  LayoutContext copyWith({
    LayoutDeviceType? device,
    String? role,
    String? entityId,
  }) {
    return LayoutContext(
      device: device ?? this.device,
      role: role ?? this.role,
      entityId: entityId ?? this.entityId,
    );
  }

  /// ============================================================
  /// VALUE COMPARISON (IMPORTANT FOR DIFF + CACHE)
  /// ============================================================

  @override
  bool operator ==(Object other) {
    return other is LayoutContext &&
        other.device == device &&
        other.role == role &&
        other.entityId == entityId;
  }

  @override
  int get hashCode => Object.hash(
        device,
        role,
        entityId,
      );
}