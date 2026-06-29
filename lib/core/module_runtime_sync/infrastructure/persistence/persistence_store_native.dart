/// Native implementation (mobile/desktop) — uses SQLite.
library;
import 'sqlite_persistence_facade.dart';
import 'persistence_store.dart';

PersistenceStore createPlatformStore() {
  return SqlitePersistenceFacade();
}
