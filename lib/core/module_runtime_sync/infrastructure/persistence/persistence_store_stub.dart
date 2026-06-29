/// Stub — provides the fallback implementation.
/// Will be overridden by conditional imports.
library;
import 'persistence_store.dart';

PersistenceStore createPlatformStore() {
  throw UnsupportedError(
    'PersistenceStore: No platform implementation available.',
  );
}
