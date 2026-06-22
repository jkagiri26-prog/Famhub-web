import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/context_storage_service.dart';
import '../services/context_sync_service.dart';

final contextStorageServiceProvider =
    Provider<ContextStorageService>((ref) {
  return ContextStorageService();
});

final contextSyncServiceProvider =
    Provider<ContextSyncService>((ref) {
  return ContextSyncService();
});