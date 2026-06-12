import 'package:famhub_app/core/dashboard_engine/domain/value_objects/module_key.dart';

/// ============================================================
/// DASHBOARD MODULE (RUNTIME SAFE SNAPSHOT)
/// ============================================================
///
/// Pure dashboard-engine representation of a system module.
///
/// This is a READ-ONLY runtime snapshot used ONLY for:
/// - composition engine
/// - renderer
///
/// ❌ NOT system module definition
/// ❌ NOT registry entry
/// ❌ NOT business logic entity
/// ============================================================
class DashboardModule {
  final ModuleKey key;

  /// Whether module is allowed to appear in dashboard UI
  final bool isVisible;

  /// Whether module participates in dashboard composition
  final bool isDashboardEnabled;

  /// Optional grouping hint for UI rendering only
  final String? group;

  /// Lightweight metadata (UI hints only, NOT logic)
  final Map<String, dynamic> metadata;

  const DashboardModule({
    required this.key,
    required this.isVisible,
    required this.isDashboardEnabled,
    this.group,
    this.metadata = const {},
  });

  /// ============================================================
  /// SAFE FACTORY (FROM ADAPTER OUTPUT ONLY)
  /// ============================================================
  factory DashboardModule.fromMap(Map<String, dynamic> map) {
    final keyValue = map['key']?.toString() ?? '';

    return DashboardModule(
      key: ModuleKey(keyValue),
      isVisible: map['is_visible'] == true,
      isDashboardEnabled: map['dashboard_visible'] == true,
      group: map['group']?.toString(),
      metadata: Map<String, dynamic>.from(
        map['metadata'] ?? {},
      ),
    );
  }

  /// ============================================================
  /// IMMUTABLE COPY
  /// ============================================================
  DashboardModule copyWith({
    bool? isVisible,
    bool? isDashboardEnabled,
    String? group,
    Map<String, dynamic>? metadata,
  }) {
    return DashboardModule(
      key: key,
      isVisible: isVisible ?? this.isVisible,
      isDashboardEnabled:
          isDashboardEnabled ?? this.isDashboardEnabled,
      group: group ?? this.group,
      metadata: metadata ?? this.metadata,
    );
  }
}