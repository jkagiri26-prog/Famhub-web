/// Web implementation — uses in-memory store.
library;
import 'memory_persistence_store.dart';
import 'persistence_store.dart';

PersistenceStore createPlatformStore() {
  return MemoryPersistenceStore();
}
