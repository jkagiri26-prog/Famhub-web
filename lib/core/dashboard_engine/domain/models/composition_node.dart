import 'package:flutter/foundation.dart';

/// ============================================================
/// COMPOSITION NODE (DOMAIN CORE)
/// ============================================================
///
/// A single unit in the dashboard composition graph.
///
/// This is NOT UI.
/// This is NOT a widget.
/// This is NOT a module.
///
/// It is a STRUCTURAL RENDER INSTRUCTION.
/// ============================================================
@immutable
class CompositionNode {
  /// Unique node identifier in composition tree
  final String id;

  /// Source module key (NOT authority, just reference)
  final String moduleKey;

  /// Widget identifier to be rendered
  final String widgetKey;

  /// Logical grouping zone (header, main, sidebar, etc.)
  final String zone;

  /// Order inside its zone
  final int order;

  /// Optional runtime payload for renderer
  final Map<String, dynamic> payload;

  /// Visibility flag after composition resolution
  final bool isVisible;

  const CompositionNode({
    required this.id,
    required this.moduleKey,
    required this.widgetKey,
    required this.zone,
    required this.order,
    this.payload = const {},
    this.isVisible = true,
  });

  /// Copy helper for diff engine updates
  CompositionNode copyWith({
    String? id,
    String? moduleKey,
    String? widgetKey,
    String? zone,
    int? order,
    Map<String, dynamic>? payload,
    bool? isVisible,
  }) {
    return CompositionNode(
      id: id ?? this.id,
      moduleKey: moduleKey ?? this.moduleKey,
      widgetKey: widgetKey ?? this.widgetKey,
      zone: zone ?? this.zone,
      order: order ?? this.order,
      payload: payload ?? this.payload,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CompositionNode &&
        other.id == id &&
        other.moduleKey == moduleKey &&
        other.widgetKey == widgetKey &&
        other.zone == zone &&
        other.order == order &&
        other.isVisible == isVisible;
  }

  @override
  int get hashCode => Object.hash(
        id,
        moduleKey,
        widgetKey,
        zone,
        order,
        isVisible,
      );
}