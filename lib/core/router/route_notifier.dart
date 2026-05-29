import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../context_engine/providers/context_provider.dart';

final routeNotifierProvider =
    ChangeNotifierProvider<RouteNotifier>((ref) {
  final notifier = RouteNotifier(ref);

  ref.listen(
    contextProvider,
    (_, __) {
      notifier.notifyListeners();
    },
  );

  return notifier;
});

class RouteNotifier extends ChangeNotifier {
  final Ref ref;

  RouteNotifier(this.ref);

  void refresh() {
    notifyListeners();
  }
}