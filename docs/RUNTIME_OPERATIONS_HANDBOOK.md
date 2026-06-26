# Runtime Operations Handbook

> **Phase 6 — TASK G3**: Production operational procedures for the Dashboard Runtime Engine.

---

## Table of Contents

1. [Recovery Procedures](#1-recovery-procedures)
2. [Corruption Recovery Steps](#2-corruption-recovery-steps)
3. [Replay Troubleshooting](#3-replay-troubleshooting)
4. [Log Interpretation](#4-log-interpretation)
5. [Checkpoint Maintenance](#5-checkpoint-maintenance)
6. [Compaction Guidance](#6-compaction-guidance)
7. [Performance Tuning](#7-performance-tuning)

---

## 1. Recovery Procedures

### Startup Recovery Flow

On each app start, the engine follows this sequence:

```
┌─────────────────────────────────────────────────────┐
│ 1. Checkpoint Restore ───────────────────────────── │
│    Load latest valid checkpoint                      │
│    If corrupted → fallback to previous checkpoint    │
│    If no valid checkpoints → start from initial      │
│    state (full journal replay on next step)          │
├─────────────────────────────────────────────────────┤
│ 2. Widget Hydration ─────────────────────────────── │
│    Fetch current widget state from backend REST API  │
│    Populate WidgetStateStore                         │
├─────────────────────────────────────────────────────┤
│ 3. Journal Delta Replay ─────────────────────────── │
│    Replay events since checkpoint seq_id             │
│    Adaptive batching prevents UI thread freeze       │
│    Invalid/corrupted rows safely skipped             │
├─────────────────────────────────────────────────────┤
│ 4. Pipeline Execution ───────────────────────────── │
│    Reconcile → Diff → Patch → Execute                │
├─────────────────────────────────────────────────────┤
│ 5. Realtime Subscription ────────────────────────── │
│    Subscribe to Postgres changes                     │
│    Exponential backoff on disconnect                 │
└─────────────────────────────────────────────────────┘
```

### Graceful Shutdown

When the engine is being disposed (app termination):

```
1. Cancel coalescing timer
2. Cancel reconnect timer
3. Unsubscribe realtime channel
4. Drain pending events through pipeline
5. Force checkpoint save of final state
```

### Crash Recovery Matrix

| Crash Point | Effect | Recovery |
|-------------|--------|----------|
| Before checkpoint save | Last checkpoint + full journal replay | No data loss |
| During checkpoint save | Either old or new checkpoint valid | No corruption |
| After checkpoint save | New checkpoint + pruned journal | Fast startup |
| During journal append | Event may be lost (at-most-once for crash) | Journal seq continuity |
| During pipeline exec | State may be partially applied | Replay corrects |
| During widget hydration | Widget state stale | Next hydration fixes |
| During compaction | Journal may retain duplicate rows | Harmless (skipped on replay) |

---

## 2. Corruption Recovery Steps

### Journal Corruption

Symptoms in logs:
```
[EventJournal] WARNING: Corrupted journal row: missing or empty entity_id
[EventJournal] WARNING: Failed to convert journal row seq_id=X to event
```

**Automatic recovery**: The journal's `_safeRowToEvent()` method skips corrupted rows during replay. No manual intervention needed.

**Manual recovery** (if startup hangs or fails):

1. Check journal database integrity:
   ```sql
   PRAGMA integrity_check;
   ```

2. If corruption detected, the journal can be manually truncated:
   ```sql
   DELETE FROM event_journal WHERE seq_id <= last_valid_seq_id;
   ```

3. Replay from a known good checkpoint.

### Checkpoint Corruption

Symptoms:
```
[CheckpointStore] WARNING: Invalid checkpoint skipped
[RuntimeSyncEngine] No valid checkpoint found. Will use full journal replay.
```

**Automatic recovery**: The store falls back to the previous checkpoint (if available). If both are corrupted, full journal replay restores correctness (just slower).

**Manual recovery**:

1. Verify checkpoint table:
   ```sql
   SELECT id, schema_version, last_sequence_id, created_at
   FROM runtime_checkpoints ORDER BY id DESC;
   ```

2. Delete corrupted checkpoints:
   ```sql
   DELETE FROM runtime_checkpoints WHERE id = <corrupted_id>;
   ```

---

## 3. Replay Troubleshooting

### Common Issues

| Symptom | Likely Cause | Solution |
|---------|-------------|----------|
| Replay very slow (>10s for 10K) | Checkpoint missing or stale | Force checkpoint save |
| Excessive log warnings about ordering | Duplicate seq_ids in journal | Compact journal |
| High memory during replay | Large backlog without batching | Re-enable adaptive batching |
| UI jank during replay | Batching disabled | Set `enableAdaptiveBatching=true` |

### Replay Metrics Interpretation

Logged at init completion:
```
[RuntimeSyncEngine] Replay complete: 5000 events replayed, 1200ms duration, 4166 events/sec, 100 adaptive batches
```

- **Events/sec > 1000**: Normal operation
- **Events/sec 100-1000**: Degraded (consider checkpoint optimization)
- **Events/sec < 100**: Investigate (disk I/O, CPU contention)

### Forcing Replay

To force a full replay from scratch:
1. Delete checkpoint database file
2. Restart engine
3. Engine falls back to full journal replay

---

## 4. Log Interpretation

### Log Levels

The engine uses a single log level (print-based) with structured prefixes:

```
[RuntimeSyncEngine] INFO: Normal operational messages
[RuntimeSyncEngine] WARNING: Degraded but recoverable conditions
[EventJournal] WARNING: Data integrity warnings
[CheckpointStore] WARNING: Checkpoint validation failures
```

### Key Log Patterns

**Normal startup**:
```
[RuntimeSyncEngine] Starting initialization...
[RuntimeSyncEngine] Initializing persistence layers...
[RuntimeSyncEngine] Restoring checkpoint...
[RuntimeSyncEngine] Checkpoint restored: seq=1250, duration=15ms
[RuntimeSyncEngine] Hydrating widget state...
[RuntimeSyncEngine] Replaying 50 events from seq_id > 1250...
[RuntimeSyncEngine] Replay complete: 50 events, 12ms, 4166 eps, 1 batches
[RuntimeSyncEngine] Subscribing to realtime changes...
[RuntimeSyncEngine] Realtime subscription active.
[RuntimeSyncEngine] Initialization complete.
```

**Degraded startup** (no checkpoint):
```
[RuntimeSyncEngine] No valid checkpoint found. Will use full journal replay.
[RuntimeSyncEngine] Replaying 15000 events from seq_id > 0...
[RuntimeSyncEngine] Replay complete: 15000 events, 3200ms, 4687 eps, 300 batches
```

**Buffer overflow**:
```
[RuntimeSyncEngine] WARNING: Buffer near capacity (450/500).
[RuntimeSyncEngine] WARNING: Buffer overflow! (501 events).
```

---

## 5. Checkpoint Maintenance

### Checkpoint Policy

- **Frequency**: Every 25 pipeline executions
- **Retention**: 2 checkpoints retained (latest + previous fallback)
- **Storage**: Separate SQLite database (`dashboard_checkpoint.db`)

### Manual Operations

**Force checkpoint**:
```dart
await engine._trySaveCheckpoint(force: true);
```

**View checkpoint status**:
```dart
final metrics = engine.runtimeMetrics;
print('Last checkpoint seq: ${metrics['lastCheckpointSequence']}');
```

**Clear checkpoints** (forces full replay on next restart):
```dart
await checkpointStore.clear();
```

### Best Practices

- ✅ Keep checkpoints enabled in production
- ✅ Ensure 25 pipeline execution interval for typical workloads
- ⚠️ For very high-event workloads (>100 events/sec), reduce interval to 10-15
- ❌ Never set retention to 0 (loses fallback safety)

---

## 6. Compaction Guidance

### Compaction Policy

- **Trigger**: After every successful checkpoint save
- **Scope**: Removes journal events with `seq_id <= checkpoint_seq_id`
- **Safety**: Only runs after checkpoint is confirmed saved

### VACUUM (Disk Space Recovery)

- **Trigger**: After large prune operations, when app is idle
- **Effect**: Reclaims SQLite free pages, reduces file size
- **Caveat**: Blocks database access during VACUUM

### Estimated Disk Usage

| Events | Journal Size | After Compaction | After VACUUM |
|--------|-------------|-------------------|--------------|
| 1,000  | ~200 KB     | ~50 KB            | ~30 KB       |
| 10,000 | ~2 MB       | ~500 KB           | ~300 KB      |
| 100,000| ~20 MB      | ~5 MB             | ~3 MB        |
| 1,000,000| ~200 MB   | ~50 MB            | ~30 MB       |

### Configuration

```dart
// In RuntimeSyncEngine constructor:
RuntimeSyncEngine(
  enableCompaction: true,  // Enable journal compaction
  // ...
);
```

---

## 7. Performance Tuning

### Feature Flags

```dart
RuntimeSyncEngine(
  enableCheckpointing: true,    // Enable periodic checkpoints
  enableCompaction: true,       // Journal compaction after checkpoint
  enableReplayMetrics: true,    // Collect replay diagnostics
  enableAdaptiveBatching: true, // Adaptive batch sizing during replay
);
```

### Tuning Parameters

| Parameter | Default | Range | Effect |
|-----------|---------|-------|--------|
| `_coalescingWindow` | 32ms | 16-50ms | Higher = more batching, lower = lower latency |
| `_replayBaseBatchSize` | 50 | 20-200 | Lower = smoother UI, higher = faster replay |
| `_replayLargeBatchSize` | 200 | 50-500 | Affects small-backlog replay speed |
| `_replayLargeBacklogThreshold` | 100 | 50-500 | Threshold for switching batch sizes |
| `_maxBufferedEvents` | 500 | 100-2000 | Memory limit for conflict buffer |
| `_maxReplayEvents` | 5000 | 1000-50000 | Max events replayed per startup |
| `_checkpointInterval` | 25 | 5-100 | Pipeline runs between checkpoints |
| `_maxRetainedCheckpoints` | 2 | 1-5 | Checkpoints kept (higher = more fallback safety) |
| `_backoffInitial` | 1s | 0.1-5s | Initial reconnect backoff delay |
| `_backoffMax` | 30s | 10-120s | Maximum backoff cap |

### Performance Budgets

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Startup time (cold) | < 3s | 3-10s | > 10s |
| Replay: 10K events | < 2s | 2-5s | > 5s |
| Replay: 100K events | < 10s | 10-20s | > 20s |
| Memory (buffer) | < 1 MB | 1-5 MB | > 5 MB |
| Journal size | < 10 MB | 10-100 MB | > 100 MB |
| Coalescing latency | < 32ms | 32-100ms | > 100ms |
| Pipeline execution | < 50ms | 50-200ms | > 200ms |

### Monitoring Queries

```sql
-- Journal size
SELECT COUNT(*) AS event_count FROM event_journal;
SELECT MAX(seq_id) AS max_seq FROM event_journal;

-- Checkpoint status
SELECT id, schema_version, last_sequence_id, created_at
FROM runtime_checkpoints ORDER BY id DESC LIMIT 2;

-- Checkpoint gap (events since last checkpoint)
SELECT (
  SELECT MAX(seq_id) FROM event_journal
) - (
  SELECT MAX(last_sequence_id) FROM runtime_checkpoints
) AS replay_gap;
```

---

## Appendix: Architecture Reference

```
Realtime (Supabase)
     │
     ▼
┌─────────────────────────────┐
│  EventJournal (SQLite)      │  ← Append-only, crash-safe
│  - seq_id (PK, AUTOINC)     │
│  - entity_id + timestamp    │
│  - source + payload (JSON)  │
└─────────┬───────────────────┘
          │ replay
          ▼
┌─────────────────────────────┐
│  ConflictBuffer (Memory)    │  ← Ordering + staleness dedup
│  - maxBufferSize = 500      │
│  - Overflow detection (A3)  │
└─────────┬───────────────────┘
          │ resolveAll()
          ▼
┌─────────────────────────────┐
│  Pipeline Orchestrator       │  ← Stages: reconcile → diff → patch → execute
│  - Coalescing window (A1)   │
│  - Diff short-circuit (C1)  │
└─────────┬───────────────────┘
          │ updateState()
          ▼
┌─────────────────────────────┐
│  ModuleRuntimeState         │  ← Provider state
│  (StateNotifier)            │
└─────────┬───────────────────┘
          │ every 25 runs
          ▼
┌─────────────────────────────┐
│  CheckpointStore (SQLite)   │  ← Materialized state snapshot
│  - Retention: 2             │
│  - Transaction-atomic save  │
└─────────┬───────────────────┘
          │ on save
          ▼
┌─────────────────────────────┐
│  Journal Compaction         │  ← Prune checkpointed events
│  + VACUUM (idle)            │
└─────────────────────────────┘
```

---

*Handbook version: 1.0 — Phase 6 Production Readiness*
*Last updated: December 2024*
