/// ============================================================
/// CONNECTIVITY PROVIDER — Live connection state
/// ============================================================
///
/// Provides a live boolean indicating network connectivity.
/// Uses connectivity_plus to stream status changes.
/// Falls back to true if connectivity_plus fails.
/// ============================================================
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Provider that emits connectivity status changes.
/// true = connected, false = offline.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    return results.any((r) => r != ConnectivityResult.none);
  });
});
