/// ============================================================
/// PERSISTENCE STORE FACTORY
/// ============================================================
///
/// Uses conditional imports to select the correct implementation
/// per platform. No kIsWeb checks in business logic.
///
/// Web → MemoryPersistenceStore
/// Mobile/Desktop → SQLitePersistenceStore
/// ============================================================

import 'persistence_store.dart';
import 'persistence_store_stub.dart'
    if (dart.library.io) 'persistence_store_native.dart'
    if (dart.library.html) 'persistence_store_web.dart';

/// Create the appropriate PersistenceStore for the current platform.
PersistenceStore createPersistenceStore() {
  return createPlatformStore();
}
