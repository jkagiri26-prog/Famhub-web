import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'context_notifier.dart';
import 'app_context.dart';

final contextProvider =
    StateNotifierProvider<ContextNotifier, AppContext>((ref) {
  return ContextNotifier();
});