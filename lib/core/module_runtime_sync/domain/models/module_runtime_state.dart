import 'package:flutter/foundation.dart';

class ModuleRuntimeState {
  const ModuleRuntimeState({
    required this.activeModules,
    required this.disabledModules,
    required this.maintenanceModules,
    required this.lastSyncedAt,
  });

  final Set<String> activeModules;
  final Set<String> disabledModules;
  final Set<String> maintenanceModules;

  final DateTime? lastSyncedAt;

  factory ModuleRuntimeState.initial() {
    return const ModuleRuntimeState(
      activeModules: <String>{},
      disabledModules: <String>{},
      maintenanceModules: <String>{},
      lastSyncedAt: null,
    );
  }

  ModuleRuntimeState copyWith({
    Set<String>? activeModules,
    Set<String>? disabledModules,
    Set<String>? maintenanceModules,
    DateTime? lastSyncedAt,
  }) {
    return ModuleRuntimeState(
      activeModules: activeModules ?? this.activeModules,
      disabledModules: disabledModules ?? this.disabledModules,
      maintenanceModules: maintenanceModules ?? this.maintenanceModules,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return 'ModuleRuntimeState('
        'activeModules: $activeModules, '
        'disabledModules: $disabledModules, '
        'maintenanceModules: $maintenanceModules, '
        'lastSyncedAt: $lastSyncedAt'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ModuleRuntimeState &&
        setEquals(other.activeModules, activeModules) &&
        setEquals(other.disabledModules, disabledModules) &&
        setEquals(other.maintenanceModules, maintenanceModules) &&
        other.lastSyncedAt == lastSyncedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      activeModules,
      disabledModules,
      maintenanceModules,
      lastSyncedAt,
    );
  }
}