enum DashboardPatchActionType {
  refreshZone,
  removeWidget,
  refreshNavigation,
  invalidateDependency,
}

class DashboardRuntimePatchAction {
  const DashboardRuntimePatchAction({
    required this.type,
    required this.target,
  }) : assert(
          target.trim().isNotEmpty,
          'DashboardRuntimePatchAction.target cannot be empty',
        );

  final DashboardPatchActionType type;
  final String target;

  String get normalizedTarget => target.trim();

  @override
  bool operator ==(Object other) {
    return other is DashboardRuntimePatchAction &&
        other.type == type &&
        other.target == target;
  }

  @override
  int get hashCode => Object.hash(type, target);
}

class DashboardRuntimePatch {
  DashboardRuntimePatch({
    required List<DashboardRuntimePatchAction> actions,
  }) : actions = List.unmodifiable(
          actions
              .where((a) => a.target.trim().isNotEmpty)
              .map(
                (a) => DashboardRuntimePatchAction(
                  type: a.type,
                  target: a.target.trim(),
                ),
              ),
        );

  /// ============================================================
  /// IMMUTABLE SNAPSHOT
  /// ============================================================
  final List<DashboardRuntimePatchAction> actions;

  /// ============================================================
  /// BASIC STATE
  /// ============================================================
  bool get isEmpty => actions.isEmpty;

  bool get isNotEmpty => actions.isNotEmpty;

  int get length => actions.length;

  /// ============================================================
  /// DETERMINISTIC PATCH ID
  /// ============================================================
  ///
  /// Stable across executions as long as patch contents
  /// remain identical.
  ///
  String get id => fingerprint;

  /// ============================================================
  /// GROUPING HELPERS
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
  /// DETERMINISTIC FINGERPRINT
  /// ============================================================
  String get fingerprint {
    final hash = Object.hashAll(
      actions.map(
        (a) => Object.hash(a.type, a.target),
      ),
    );

    return hash.toString();
  }

  @override
  bool operator ==(Object other) {
    return other is DashboardRuntimePatch &&
        other.fingerprint == fingerprint;
  }

  @override
  int get hashCode => fingerprint.hashCode;

  @override
  String toString() {
    return 'DashboardRuntimePatch('
        'actions: ${actions.length}, '
        'id: $id'
        ')';
  }
}