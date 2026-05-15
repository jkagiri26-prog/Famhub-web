import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkMonitor {
  Stream<bool> get onStatusChange async* {
    await for (final result in Connectivity().onConnectivityChanged) {
      yield result != ConnectivityResult.none;
    }
  }
}