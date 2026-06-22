import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemState {
  final bool isSystemDown;

  const SystemState({
    this.isSystemDown = false,
  });

  SystemState copyWith({
    bool? isSystemDown,
  }) {
    return SystemState(
      isSystemDown: isSystemDown ?? this.isSystemDown,
    );
  }
}

/// ============================================================
/// SYSTEM STATE NOTIFIER (RIVERPOD 3)
/// ============================================================
class SystemStateNotifier extends Notifier<SystemState> {
  @override
  SystemState build() {
    return const SystemState();
  }

  void setMaintenanceMode(bool value) {
    state = state.copyWith(
      isSystemDown: value,
    );
  }
}

/// ============================================================
/// PROVIDER
/// ============================================================
final systemStateProvider =
    NotifierProvider<SystemStateNotifier, SystemState>(
  SystemStateNotifier.new,
);