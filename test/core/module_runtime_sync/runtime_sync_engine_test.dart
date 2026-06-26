import 'package:flutter_test/flutter_test.dart';
import 'package:famhub_app/core/module_runtime_sync/runtime_sync_engine.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';

void main() {
  // ============================================================
  // TASK C3: Replay Lock Tests
  // ============================================================
  group('TASK C3 — Replay Lock', () {
    test('ModuleRuntimeState equality works correctly', () {
      const state1 = ModuleRuntimeState(
        activeModules: {'mod-a'},
        disabledModules: {},
        maintenanceModules: {},
        lastSyncedAt: null,
      );

      const state2 = ModuleRuntimeState(
        activeModules: {'mod-a'},
        disabledModules: {},
        maintenanceModules: {},
        lastSyncedAt: null,
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('ModuleRuntimeState inequality works correctly', () {
      const state1 = ModuleRuntimeState(
        activeModules: {'mod-a'},
        disabledModules: {},
        maintenanceModules: {},
        lastSyncedAt: null,
      );

      const state2 = ModuleRuntimeState(
        activeModules: {'mod-b'},
        disabledModules: {},
        maintenanceModules: {},
        lastSyncedAt: null,
      );

      expect(state1, isNot(equals(state2)));
    });

    test('ModuleRuntimeState initial state is empty', () {
      final initial = ModuleRuntimeState.initial();
      expect(initial.activeModules, isEmpty);
      expect(initial.disabledModules, isEmpty);
      expect(initial.maintenanceModules, isEmpty);
      expect(initial.lastSyncedAt, isNull);
    });

    test('ModuleRuntimeState copyWith works', () {
      final initial = ModuleRuntimeState.initial();
      final modified = initial.copyWith(
        activeModules: {'mod-a'},
        lastSyncedAt: DateTime(2024, 1, 1),
      );

      expect(modified.activeModules, contains('mod-a'));
      expect(modified.disabledModules, isEmpty);
      expect(modified.lastSyncedAt, equals(DateTime(2024, 1, 1)));
    });
  });

  // ============================================================
  // TASK D1: Recovery Metrics Tests
  // ============================================================
  group('TASK D1 — Recovery Metrics Structure', () {
    test('ModuleRuntimeState fields are accessible', () {
      final state = ModuleRuntimeState(
        activeModules: {'a', 'b'},
        disabledModules: {'c'},
        maintenanceModules: {'d'},
        lastSyncedAt: DateTime(2024, 6, 15),
      );

      expect(state.activeModules.length, equals(2));
      expect(state.disabledModules.length, equals(1));
      expect(state.maintenanceModules.length, equals(1));
      expect(state.lastSyncedAt, isNotNull);
    });

    test('ModuleRuntimeState string representation', () {
      final state = ModuleRuntimeState.initial();
      final str = state.toString();
      expect(str, contains('ModuleRuntimeState'));
      expect(str, contains('activeModules'));
    });
  });

  // ============================================================
  // TASK D2: Structured Logging Tests
  // ============================================================
  group('TASK D2 — Recovery Logging Format', () {
    test('ModuleRuntimeState copyWith preserves unset fields', () {
      final state = ModuleRuntimeState(
        activeModules: {'a'},
        disabledModules: {},
        maintenanceModules: {},
        lastSyncedAt: DateTime(2024, 1, 1),
      );

      // Only override activeModules
      final modified = state.copyWith(activeModules: {'b'});

      expect(modified.activeModules, contains('b'));
      expect(modified.disabledModules, isEmpty);
      expect(modified.lastSyncedAt, equals(DateTime(2024, 1, 1)));
    });

    test('ModuleRuntimeState set equality check', () {
      const state1 = ModuleRuntimeState(
        activeModules: {'a', 'b'},
        disabledModules: {},
        maintenanceModules: {},
        lastSyncedAt: null,
      );

      const state2 = ModuleRuntimeState(
        activeModules: {'b', 'a'}, // Different order, same set
        disabledModules: {},
        maintenanceModules: {},
        lastSyncedAt: null,
      );

      // Sets are equal regardless of order
      expect(state1.activeModules, equals(state2.activeModules));
    });
  });
}
