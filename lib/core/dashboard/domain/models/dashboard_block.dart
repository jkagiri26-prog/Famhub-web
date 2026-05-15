import 'package:flutter/foundation.dart';

@immutable
class DashboardBlock {
  final String id;
  final String moduleKey;

  /// Logical grouping (NOT widget-level key anymore)
  final String blockKey;

  /// header | main | sidebar | footer | custom
  final String zone;

  /// Layout configuration for grouping widgets
  final Map<String, dynamic> layoutConfig;

  final int displayOrder;
  final bool isActive;

  const DashboardBlock({
    required this.id,
    required this.moduleKey,
    required this.blockKey,
    required this.zone,
    required this.layoutConfig,
    required this.displayOrder,
    required this.isActive,
  });

  factory DashboardBlock.fromMap(Map<String, dynamic> map) {
    return DashboardBlock(
      id: map['id']?.toString() ?? '',
      moduleKey: map['module_key'] ?? '',
      blockKey: map['block_key'] ?? '',
      zone: map['zone'] ?? 'main',
      layoutConfig: Map<String, dynamic>.from(
        map['layout_config'] ?? {},
      ),
      displayOrder: map['display_order'] ?? 0,
      isActive: map['is_active'] ?? true,
    );
  }
}