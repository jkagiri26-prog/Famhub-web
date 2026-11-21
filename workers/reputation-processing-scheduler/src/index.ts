// ============================================================================
// Reputation Processing Scheduler — Cloudflare Worker
// Scheduled-only handler. No public fetch endpoint.
// ============================================================================

type WorkerEnv = {
  REPUTATION_FUNCTION_URL?: string;
  REPUTATION_WORKER_SECRET?: string;
};

type ScheduledController = {
  scheduledTime: number;
  cron: string;
};

type ExecutionContext = {
  waitUntil(promise: Promise<unknown>): void;
};

type WorkerResult = {
  ok: true;
  run_id: string;
  worker_id: string;
  claimed: number;
  succeeded: number;
  retryable: number;
  dead_lettered: number;
  failed: number;
  skipped: number;
  duration_ms: number;
};

const REQUEST_TIMEOUT_MS = 60_000;
const BATCH_LIMIT = 5;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim() !== "";
}

function parseWorkerResult(value: unknown): WorkerResult | null {
  if (!isRecord(value)) return null;
  if (value.ok !== true) return null;
  if (!isNonEmptyString(value.run_id)) return null;
  if (!isNonEmptyString(value.worker_id)) return null;

  const counts = [
    value.claimed,
    value.succeeded,
    value.retryable,
    value.dead_lettered,
    value.failed,
    value.skipped,
    value.duration_ms,
  ];
  if (counts.some((count) => !isNonNegativeInteger(count))) return null;

  return {
    ok: true,
    run_id: value.run_id,
    worker_id: value.worker_id,
    claimed: value.claimed as number,
    succeeded: value.succeeded as number,
    retryable: value.retryable as number,
    dead_lettered: value.dead_lettered as number,
    failed: value.failed as number,
    skipped: value.skipped as number,
    duration_ms: value.duration_ms as number,
  };
}

function classifyError(error: unknown): string {
  const name =
    typeof error === "object" && error !== null && "name" in error
      ? String(error.name)
      : "request_error";

  if (name === "TimeoutError" || name === "AbortError") return "timeout";
  if (name === "TypeError") return "network_error";
  return "request_error";
}

function log(payload: Record<string, unknown>): void {
  console.log(JSON.stringify({
    worker: "reputation-processing-scheduler",
    ...payload,
  }));
}

export default {
  async scheduled(
    _controller: ScheduledController,
    env: WorkerEnv,
    _ctx: ExecutionContext,
  ): Promise<void> {
    const started = performance.now();
    const url = env.REPUTATION_FUNCTION_URL;
    const secret = env.REPUTATION_WORKER_SECRET;

    if (!url || !secret) {
      log({
        level: "error",
        outcome: "missing_configuration",
        duration_ms: Math.round(performance.now() - started),
      });
      return;
    }

    let response: Response;
    try {
      response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-worker-secret": secret,
        },
        body: JSON.stringify({ limit: BATCH_LIMIT }),
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });
    } catch (error) {
      log({
        level: "error",
        outcome: "request_failed",
        error_class: classifyError(error),
        duration_ms: Math.round(performance.now() - started),
      });
      return;
    }

    if (response.status !== 200) {
      log({
        level: "error",
        outcome: "http_error",
        status: response.status,
        duration_ms: Math.round(performance.now() - started),
      });
      return;
    }

    let payload: unknown;
    try {
      payload = await response.json();
    } catch (_) {
      log({
        level: "error",
        outcome: "invalid_response",
        status: response.status,
        error_class: "invalid_json",
        duration_ms: Math.round(performance.now() - started),
      });
      return;
    }

    const result = parseWorkerResult(payload);
    if (!result) {
      log({
        level: "error",
        outcome: "invalid_response",
        status: response.status,
        error_class: "contract_validation",
        duration_ms: Math.round(performance.now() - started),
      });
      return;
    }

    log({
      level: "info",
      outcome: "completed",
      run_id: result.run_id,
      worker_id: result.worker_id,
      status: response.status,
      claimed: result.claimed,
      succeeded: result.succeeded,
      retryable: result.retryable,
      dead_lettered: result.dead_lettered,
      failed: result.failed,
      skipped: result.skipped,
      duration_ms: result.duration_ms,
    });
  },
};
