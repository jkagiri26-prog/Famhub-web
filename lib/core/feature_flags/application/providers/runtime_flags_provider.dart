import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runtime feature flags notifier
class RuntimeFlagsNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  void setFlag(String key, bool value) {
    state = {...state, key: value};
  }

  void removeFlag(String key) {
    final updated = Map<String, bool>.from(state);
    updated.remove(key);
    state = updated;
  }

  void clear() => state = {};
}

final runtimeFlagsProvider =
    NotifierProvider<RuntimeFlagsNotifier, Map<String, bool>>(
  RuntimeFlagsNotifier.new,
);
