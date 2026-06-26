/// Native implementation (mobile/desktop) — uses SQLite.
import 'sqlite_persistence_facade.dart';
import 'persistence_store.dart';

PersistenceStore _createPlatformStore() {
  return SqlitePersistenceFacade();
}
