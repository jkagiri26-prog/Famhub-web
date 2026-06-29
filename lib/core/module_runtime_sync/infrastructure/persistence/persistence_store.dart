/// ============================================================
/// PERSISTENCE STORE — Platform Abstraction Boundary
/// ============================================================
///
/// 🧠 ROLE:
///   Abstract interface for event journal and checkpoint persistence.
///   Allows SQLite on mobile/desktop and Memory/IndexedDB on web.
///
/// ✅ RULES:
///   - Business logic MUST NOT know about SQLite, IndexedDB, or files
///   - Platform differences belong in infrastructure ONLY
///   - No kIsWeb checks outside this layer
/// ============================================================
library;

import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_event.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';

/// ============================================================
/// ABSTRACT PERSISTENCE STORE
/// ============================================================
abstract class PersistenceStore {
  /// Initialize the store (create tables, open connections, etc.)
  Future<void> initialize();

  /// ============================================================
  /// EVENT JOURNAL OPERATIONS
  /// ============================================================

  /// Append an event to the journal. Returns the new seq_id.
  Future<int> appendEvent(ConflictEvent event);

  /// Read all events after a given seq_id (for replay).
  Future<List<ConflictEvent>> readEventsAfter(int seqId);

  /// Get the highest seq_id in the journal.
  Future<int?> getLastEventSequenceId();

  /// Remove events with seq_id <= given id (compaction).
  Future<void> pruneEventsBefore(int sequenceId);

  /// Get total event count.
  Future<int> getEventCount();

  /// ============================================================
  /// CHECKPOINT OPERATIONS
  /// ============================================================

  /// Save a runtime checkpoint.
  Future<void> saveCheckpoint({
    required int lastSequenceId,
    required ModuleRuntimeState moduleState,
  });

  /// Load the latest valid checkpoint, or null.
  Future<ModuleRuntimeState?> loadLatestCheckpoint();

  /// Clear all data (for testing/reset).
  Future<void> clear();

  /// ============================================================
  /// LIFECYCLE
  /// ============================================================
  Future<void> dispose();
}
