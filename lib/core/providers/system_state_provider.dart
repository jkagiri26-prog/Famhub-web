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

class SystemStateNotifier extends StateNotifier<SystemState> {
  SystemStateNotifier() : super(const SystemState());

  void setMaintenanceMode(bool value) {
    state = state.copyWith(
      isSystemDown: value,
    );
  }
}

final systemStateProvider =
    StateNotifierProvider<SystemStateNotifier, SystemState>(
  (ref) => SystemStateNotifier(),
);