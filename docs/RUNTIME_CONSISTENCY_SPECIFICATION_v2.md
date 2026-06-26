# Runtime Consistency Specification v2

> **Document Version:** 2.0  
> **Phase:** 5.5 — Production Hardening  
> **Status:** ✅ Final  
> **Applies to:** `RuntimeSyncEngine`, `EventJournal`, `RuntimeCheckpointStore`, `ConflictBuffer`

---

## 1. Consistency Model

### 1.1 Eventual Consistency with Crash Recovery

The Dashboard Runtime Engine provides **crash-safe eventual consistency**. Under normal operation, state converges monotonically as events flow through the pipeline. Under crash-and-restart, state is recovered deterministically from durable journal + checkpoint snapshots.

### 1.2 Ordering Guarantees

| Property | Guarantee |
|----------|-----------|
| Event Ordering | Strict FIFO within a single engine instance — events processed in journal insertion order |
| Conflict Resolution | Latest timestamp wins per entity; stable ordering preserved |
| Replay Ordering | Strictly monotonic `seq_id` — duplicates and out-of-order entries detected and skipped |

### 1.3 Concurrency Model

- **Single-threaded pipeline:** All event processing is sequential within a single isolate
- **Replay lock:** Prevents live ingestion during startup replay (TASK C3)
- **Staleness guard:** Events older than current buffered state per entity are rejected
- **No concurrent transactions:** SQLite serializes all database access

---

## 2. Recovery Guarantees

### 2.1 Startup Recovery Order

1. **Bootstrap coordinator** — loads module definitions
2. **Open persistence databases** — journal + checkpoint stores
3. **Restore from checkpoint** — load latest valid checkpoint (or fallback to previous)
4. **Hydrate widget state** — fetch current backend state
5. **Replay journal delta** — replay events newer than checkpoint boundary
6. **Subscribe to realtime** — only after replay completes

### 2.2 Degradation Paths

| Scenario | Behavior | Correctness |
|----------|----------|-------------|
| No checkpoint exists | Full journal replay | ✅ Correct (slower startup) |
| Latest checkpoint corrupted | Fallback to previous checkpoint | ✅ Correct |
| All checkpoints corrupted/deleted | Full journal replay | ✅ Correct |
| Journal empty + no checkpoint | Start from initial state | ✅ Correct |
| Partial journal corruption | Corrupted rows skipped, valid rows replayed | ✅ Correct |

### 2.3 Crash Recovery Matrix

| Crash Point | Recovery Behavior | Verified |
|-------------|-------------------|----------|
| Before journal append | No event persisted — no replay needed | ✅ TASK E1 |
| After journal append, before buffer | Event persisted — replayed on restart | ✅ TASK E1 |
| After buffer add, before pipeline | Event replayed from journal | ✅ TASK E1 |
| During pipeline execution | State unchanged — events replayed | ✅ TASK E1 |
| During checkpoint save | At least one valid checkpoint remains | ✅ TASK E1 |
| During journal compaction | Non-fatal — events retained if prune fails | ✅ TASK E1 |
| During replay | Next restart resumes from last valid seq_id | ✅ TASK E1 |

---

## 3. Replay Guarantees

### 3.1 Determinism

Given the **same journal input**, replay produces:
- **Identical final state** (verified by hash comparison)
- **Same event processing order**
- **Same conflict resolution outcomes**

### 3.2 Replay Lock (TASK C3)

- `_isReplaying` flag prevents live event ingestion during replay
- Events arriving during replay are queued in `_pendingDuringReplay`
- Queue is drained atomically after replay completes
- No live event can enter the pipeline before replay finishes

### 3.3 Replay Validation (TASKS A2 + A3)

Each journal row during replay is validated for:
- Valid `entity_id` (non-null, non-empty)
- Valid `source` (must match `ConflictSource` enum)
- Valid `timestamp` (must be parseable ISO 8601)
- Valid `payload` (must be JSON-decoded to `Map<String, dynamic>`)
- Monotonically increasing `seq_id` (no duplicates, no out-of-order)

Invalid rows are:
- Safely skipped
- Logged with diagnostic warning
- Never crash the replay

### 3.4 No Infinite Replay Loops

- Each event has a unique `seq_id` (SQLite AUTOINCREMENT)
- Replay only reads events with `seq_id > lastCommittedSequenceId`
- After replay, `lastCommittedSequenceId` advances past replayed events
- Next restart replays only newer events

---

## 4. Durability Guarantees

### 4.1 Journal Durability

| Aspect | Guarantee |
|--------|-----------|
| Append atomicity | ✅ Transaction-wrapped insert — fully commits or fully rolls back |
| Prune atomicity | ✅ Transaction-wrapped delete — all-or-nothing |
| Integrity | ✅ SQLite `PRAGMA integrity_check` passes after repeated crash simulation |

### 4.2 Checkpoint Durability

| Aspect | Guarantee |
|--------|-----------|
| Save atomicity | ✅ Transaction-atomic: insert new + remove old in one tx |
| Retention | ✅ Max 2 checkpoints retained (latest + fallback) |
| Corruption handling | ✅ Validation on load — corrupted checkpoints safely skipped |
| Fallback | ✅ If latest invalid → previous checkpoint used → full journal replay |

### 4.3 Loss Window

- **Before hardening:** Events could be lost between last checkpoint and crash
- **After hardening:** Graceful shutdown (`dispose()`) flushes:
  1. All pending pipeline processing
  2. All buffered events
  3. Final checkpoint save before close

Under crash (non-graceful), at most the events in the in-memory conflict buffer that were NOT yet journaled may be lost. Events persisted in the journal survive.

---

## 5. Corruption Handling

### 5.1 Checkpoint Corruption

| Condition | Behavior |
|-----------|----------|
| `schemaVersion` missing or <= 0 | Skip checkpoint, log warning |
| `lastSequenceId` missing or < 0 | Skip checkpoint, log warning |
| `createdAt` missing or unparseable | Skip checkpoint, log warning |
| `moduleState` missing or wrong type | Skip checkpoint, log warning |
| Required state fields wrong type | Skip checkpoint, log warning |
| All checkpoints corrupted | Degrade to full journal replay |

### 5.2 Journal Corruption

| Condition | Behavior |
|-----------|----------|
| `entity_id` missing or empty | Skip row, log warning, continue replay |
| `source` missing or invalid enum | Skip row, log warning, continue replay |
| `timestamp` missing or unparseable | Skip row, log warning, continue replay |
| `payload` missing or invalid JSON | Skip row, log warning, continue replay |
| `payload` decodes to non-Map type | Skip row, log warning, continue replay |
| Duplicate `seq_id` | Skip duplicate, log warning, continue replay |
| Out-of-order `seq_id` | Skip outlier, log warning, continue replay |

### 5.3 Crash Safety Philosophy

- **Checkpoints are optimizations** — losing them does not lose data
- **Journal is the source of truth** — events in journal survive crashes
- **All failures are non-fatal** — the engine degrades gracefully without crashing

---

## 6. Lifecycle Guarantees

### 6.1 App Lifecycle Hooks (TASK C1)

| Lifecycle State | Action |
|-----------------|--------|
| `AppLifecycleState.paused` | Force checkpoint save |
| `AppLifecycleState.detached` | Force checkpoint save |
| `AppLifecycleState.inactive` | Force checkpoint save |

### 6.2 Shutdown Sequence (TASK C2)

1. Unsubscribe from realtime channel
2. Drain any in-flight pipeline processing
3. Force final checkpoint save
4. Close database connections

### 6.3 Initialization Sequence

1. Bootstrap coordinator
2. Initialize persistence (journal + checkpoint DBs)
3. Restore from latest valid checkpoint
4. Hydrate widget state from backend
5. Replay journal delta (replay lock active)
6. Subscribe to realtime (replay lock released)

---

## 7. Startup Ordering Guarantees

```
initialize()
├── coordinator.bootstrap()
├── _initPersistence()
├── _restoreCheckpoint()          ← REPLAY LOCK: _isReplaying = false
├── _hydrateWidgetState()         ←   (pre-replay, no lock needed)
├── _replayDelta()                ← REPLAY LOCK: _isReplaying = true
│   ├── read journal events
│   ├── add to conflict buffer
│   ├── process pipeline
│   └── REPLAY LOCK: _isReplaying = false
└── _subscribeToModuleChanges()   ← Live events now accepted
```

**Invariant:** No live event enters the pipeline until replay completes.

---

## 8. Failure Semantics

| Component | Failure Mode | Behavior |
|-----------|-------------|----------|
| EventJournal.append() | DB write failure | Transaction rolls back — state unchanged |
| EventJournal.pruneBefore() | DB write failure | Transaction rolls back — journal intact |
| Checkpoint save | DB write failure | Transaction rolls back — previous checkpoint still valid |
| Pipeline stage failure | Exception in stage | Non-fatal — stage skipped, pipeline continues |
| Realtime subscription | Network failure | Subscription fails — events not received until reconnected |
| Journal DB open | File system failure | Engine cannot start — reported to caller |

---

## 9. Known Limitations

### 9.1 Not Guaranteed

- **Exactly-once delivery:** The engine provides at-least-once delivery; duplicates may occur on restart
- **Distributed consensus:** No Raft/Paxos — single-node consistency only
- **Cross-process locking:** No inter-process mutex — use only one engine instance per database
- **Real-time replication:** Checkpoints are local only; replication is out of scope
- **Background isolates:** All processing occurs in the main isolate

### 9.2 Acceptable Trade-offs

- **Checkpoint loss ≠ data loss:** Losing all checkpoints only increases startup latency
- **Journal growth under heavy load:** Periodic compaction bounds journal size; worst case = full journal replay
- **In-flight event loss on hard crash:** Only events not yet journaled are lost (window = microseconds)

### 9.3 Production Recommendations

1. **Monitor journal size** — alert if > 100,000 uncheckpointed events
2. **Monitor replay duration** — alert if > 5 seconds
3. **Run `PRAGMA integrity_check`** periodically on both databases
4. **Backup checkpoint DB** periodically for faster disaster recovery

---

## 10. Compliance Matrix

| Requirement | Status | TASK |
|-------------|--------|------|
| Startup replay deterministic | ✅ | A3, C3 |
| Corrupted checkpoints cannot crash startup | ✅ | B1 |
| Corrupted journal rows safely skipped | ✅ | A2 |
| Replay ordering validated | ✅ | A3 |
| Lifecycle persistence hooks wired | ✅ | C1 |
| Graceful shutdown flush implemented | ✅ | C2 |
| Recovery metrics added | ✅ | D1 |
| Structured recovery logging added | ✅ | D2 |
| Crash recovery matrix validated | ✅ | E1 |
| Replay determinism proven | ✅ | E2 |
| Long-run replay stability proven | ✅ | E3 |

---

*End of Runtime Consistency Specification v2*
