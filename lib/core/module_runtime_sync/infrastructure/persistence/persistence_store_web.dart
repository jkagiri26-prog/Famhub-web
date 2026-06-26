/// Web implementation — uses in-memory store.
import 'memory_persistence_store.dart';
import 'persistence_store.dart';

PersistenceStore _createPlatformStore() {
  return MemoryPersistenceStore();
}
