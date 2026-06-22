enum DashboardPatchActionType {
  refreshZone,
  removeWidget,
  refreshNavigation,
  invalidateDependency,
  invalidateModules,
}

class DashboardRuntimePatchAction {
  DashboardRuntimePatchAction({
    required this.type,
    required String target,
    this.payload,
  }) : target = target.trim(),
       assert(target.trim().isNotEmpty,
           'DashboardRuntimePatchAction.target cannot be empty');

  final DashboardPatchActionType type;
  final String target;
  final Map<String, dynamic>? payload;

  String get normalizedTarget => target;

  @override
  bool operator ==(Object other) {
    return other is DashboardRuntimePatchAction &&
        other.type == type &&
        other.target == target &&
        other.payload == payload;
  }

  @override
  int get hashCode => Object.hash(type, target, payload);
}

/// ============================================================
/// RUNTIME PATCH (IMMUTABLE + DETERMINISTIC)
/// ============================================================
class DashboardRuntimePatch {
  final List<DashboardRuntimePatchAction> actions;

  DashboardRuntimePatch({
    required List<DashboardRuntimePatchAction> actions,
  }) : actions = List.unmodifiable(
          actions
              .where((a) => a.target.isNotEmpty)
                            .map((a) => DashboardRuntimePatchAction(
                    type: a.type,
                    target: a.target,
                    payload: a.payload,
                  ))
              .toList()
            ..sort(_compareActions),
        );

  /// ============================================================
  /// BASIC STATE
  /// ============================================================
  bool get isEmpty => actions.isEmpty;
  bool get isNotEmpty => actions.isNotEmpty;
  int get length => actions.length;

  /// ============================================================
  /// ACTION FILTERING
  /// ============================================================
  List<DashboardRuntimePatchAction> actionsByType(
    DashboardPatchActionType type,
  ) {
    return actions
        .where((a) => a.type == type)
        .toList(growable: false);
  }

  List<String> affectedTargets() {
    return actions
        .map((a) => a.target)
        .toSet()
        .toList(growable: false);
  }

  /// ============================================================
  /// DETERMINISTIC ID (STABLE WITHIN SYSTEM)
  /// ============================================================
  String get id => _stableFingerprint();

  String _stableFingerprint() {
    final buffer = StringBuffer();

    for (final a in actions) {
      buffer.write('${a.type.name}:${a.target};');
    }

    return buffer.toString();
  }

  static int _compareActions(
    DashboardRuntimePatchAction a,
    DashboardRuntimePatchAction b,
  ) {
    final typeCompare = a.type.index.compareTo(b.type.index);
    if (typeCompare != 0) return typeCompare;

    return a.target.compareTo(b.target);
  }

  @override
  bool operator ==(Object other) {
    return other is DashboardRuntimePatch &&
        other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DashboardRuntimePatch('
        'actions: ${actions.length}, '
        'id: $id'
        ')';
  }
}