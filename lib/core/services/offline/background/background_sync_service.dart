import 'dart:async';
import '../sync_engine.dart';

class BackgroundSyncService {
  final SyncEngine syncEngine;

  Timer? _timer;

  BackgroundSyncService(this.syncEngine);

  void start() {
    _timer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncEngine.sync(),
    );
  }

  void stop() {
    _timer?.cancel();
  }
}