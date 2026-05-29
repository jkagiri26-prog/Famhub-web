import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/widget_state_store.dart';

final widgetStateStoreProvider =
    Provider<WidgetStateStore>((ref) {
  return WidgetStateStore();
});