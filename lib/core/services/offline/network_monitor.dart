import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkMonitor {
  Stream<bool> get onStatusChange async* {
    await for (final results in Connectivity().onConnectivityChanged) {
      // In connectivity_plus v6+, onConnectivityChanged returns List<ConnectivityResult>
      final resultsList = results;
      yield resultsList.any((r) => r != ConnectivityResult.none);
    }
  }
}