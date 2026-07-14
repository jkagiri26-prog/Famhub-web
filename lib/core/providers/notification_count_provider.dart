/// ============================================================
/// NOTIFICATION COUNT PROVIDER
/// ============================================================
///
/// Provides a live notification count for the shell badge.
/// Uses Notifier pattern for reactive updates.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier that tracks unread notification count.
/// Can be updated from anywhere via:
///   ref.read(unreadNotificationCountProvider.notifier).setCount(n);
class UnreadNotificationCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setCount(int count) => state = count;
  void increment() => state = state + 1;
  void decrement() {
    if (state > 0) state = state - 1;
  }

  void reset() => state = 0;
}

final unreadNotificationCountProvider =
    NotifierProvider<UnreadNotificationCountNotifier, int>(
  UnreadNotificationCountNotifier.new,
);
