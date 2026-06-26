# Runtime Operational Limits

> **Phase 6 — TASK G1**: Documented operational limits for the Dashboard Runtime Engine.

---

## 1. Maximum Supported Replay Backlog

| Level | Event Count | Performance | Expected Duration |
|-------|-------------|-------------|-------------------|
| Small | 1–1,000 | Fast (single batch) | < 200ms |
| Medium | 1,000–10,000 | Normal | 200ms–2s |
| Large | 10,000–50,000 | Adaptive batching | 2s–10s |
| Extreme | 50,000–100,000 | Degraded | 10s–20s |
| Maximum | 100,000 | Hard limit (`_maxReplayEvents`) | > 20s |

**Hard Limit**: 5,000 events per startup (`_maxReplayEvents = 5000`).
Beyond this, truncated replay occurs — remaining events require additional checkpoint cycles.

**Recommendation**: Keep checkpoint intervals such that delta replays stay under 10,000 events. For systems with >50,000 events between checkpoints, reduce `_checkpointInterval` or increase checkpoint frequency via force.

---

## 2. Safe Checkpoint Intervals

| Workload Type | Pipeline Runs Between Checkpoints | Wall Clock Equivalent |
|---------------|-----------------------------------|----------------------|
| Low-traffic | 25 | ~5 min |
| Normal | 25 | ~30 sec - 5 min |
| High-traffic | 10–15 | ~10–30 sec |
| Peak burst | 5 | ~5 sec |

**Rule**: Checkpoint should run often enough that delta replay stays under 2 seconds.

**Formula**: `maxCheckpointInterval = (2000ms × throughput_eps) / events_per_pipeline_run`

---

## 3. Recommended Compaction Thresholds

| Metric | Suggested Threshold | Action |
|--------|-------------------|--------|
| Journal row count | > 100,000 | Trigger compaction and VACUUM |
| Journal file size | > 50 MB | Trigger VACUUM (idle only) |
| Free page ratio | > 20% | Trigger VACUUM |
| Checkpoint gap | > 10,000 seq_ids | Reduce checkpoint interval |

**Compaction Safety**: Only compact events that have been fully checkpointed.
Never compact journals without a corresponding valid checkpoint.

---

## 4. Expected Replay Throughput

| Environment | Events/sec (10K) | Events/sec (50K) | Events/sec (100K) |
|-------------|------------------|------------------|-------------------|
| Emulator (debug) | 1,000–3,000 | 500–1,500 | 300–1,000 |
| Physical device (release) | 3,000–8,000 | 1,500–5,000 | 1,000–3,000 |
| High-end device (release) | 8,000–15,000 | 5,000–10,000 | 3,000–8,000 |

**Baseline**: A properly checkpointed system with < 2,000 delta events should replay in under 500ms.

---

## 5. Memory Expectations

| Component | Typical | Peak | Notes |
|-----------|---------|------|-------|
| ConflictBuffer | ~50 KB | ~2 MB | 500 events × 4KB avg |
| EventJournal (SQLite) | ~1 MB | ~100 MB | Grows with uncheckpointed events |
| CheckpointStore | ~10 KB | ~50 KB | 2 checkpoints max |
| PipelineContext | ~5 KB | ~100 KB | Per execution |
| WidgetStateStore | ~100 KB | ~10 MB | Depends on dashboard complexity |

**Total typical footprint**: 1–5 MB (excluding widget state)
**Total peak footprint**: 10–100 MB (extreme backlog + large dashboards)

---

## 6. Event Throughput Limits

| Aspect | Max Rate | Limiting Factor |
|--------|----------|-----------------|
| Journal append | 10,000 writes/sec | SQLite I/O |
| ConflictBuffer add | 50,000 ops/sec | CPU/memory |
| Pipeline execution | 200 runs/sec | Reconciliation logic |
| Replay throughput | 15,000 events/sec | SQLite read + resolution |

---

## 7. Database Connection Limits

| Database | Max Connections | Pool Size | Lock Behavior |
|----------|----------------|-----------|---------------|
| `dashboard_event_journal.db` | 1 (single) | N/A | Serialized via sqflite |
| `dashboard_checkpoint.db` | 1 (single) | N/A | Separate DB, no lock contention |

---

## 8. Startup Time Budget

| Phase | Budget | Exceeded |
|-------|--------|----------|
| Persistence init | < 50ms | > 100ms |
| Checkpoint restore | < 100ms | > 500ms |
| Widget hydration | < 500ms | > 2s |
| Journal delta replay | < 1s | > 5s |
| Realtime subscribe | < 100ms | > 500ms |
| **Total startup (cold)** | **< 2s** | **> 5s** |

---

## 9. Coalescing Window Limits

| Window Duration | Latency Impact | Pipeline Reduction | Use Case |
|----------------|---------------|-------------------|----------|
| 0ms (disable) | None | 0% | Real-time critical |
| 16ms | 16ms | ~50% | Normal operation |
| 32ms (default) | 32ms | ~75% | Balanced |
| 50ms | 50ms | ~90% | High burst tolerance |

---

## 10. Stability Guarantees

| Property | Guarantee | Mechanism |
|----------|-----------|-----------|
| No data loss | At-least-once delivery | Journal append before buffer |
| Deterministic replay | Yes | seq_id monotonic ordering |
| Crash safety | Yes | Transaction-wrapped writes |
| Memory bound | Yes | ConflictBuffer max size + overflow eviction |
| No deadlock | Yes | Non-reentrant pipeline + timer-based coalescing |
| Replay truncation | Graceful | Excess events logged, next checkpoint covers |
| Corruption tolerance | High | Row-level validation, skip corrupted rows |

---

*Document version: 1.0 — Phase 6 Production Readiness*
*Last updated: December 2024*
