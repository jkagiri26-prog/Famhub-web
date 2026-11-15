// ============================================================================
// Referral Finance Scheduler — Cloudflare Worker
// Scheduled-only handler. No public fetch endpoint.
// ============================================================================

type WorkerEnv = {
  SUPABASE_FUNCTION_URL?: string;
  REFERRAL_WORKER_SECRET?: string;
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
  gate_enabled: boolean;
  selected_count: number;
  processed_count: number;
  failed_count: number;
  run_id: string | null;
};

const REQUEST_TIMEOUT_MS = 60_000;
const BATCH_LIMIT = 20;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
}

function parseWorkerResult(value: unknown): WorkerResult | null {
  if (!isRecord(value)) return null;
  if (value.ok !== true) return null;
  if (typeof value.gate_enabled !== "boolean") return null;
  if (!isNonNegativeInteger(value.selected_count)) return null;
  if (!isNonNegativeInteger(value.processed_count)) return null;
  if (!isNonNegativeInteger(value.failed_count)) return null;

  return {
    ok: true,
    gate_enabled: value.gate_enabled,
    selected_count: value.selected_count,
    processed_count: value.processed_count,
    failed_count: value.failed_count,
    run_id: typeof value.run_id === "string" ? value.run_id : null,
  };
}

function classifyError(error: unknown): string {
  const name =
    typeof error === "object" && error !== null && "name" in error
      ? String(error.name)
      : "request_error";

  if (name === "AbortError") return "timeout";
  if (name === "TypeError") return "network_error";
  return "request_error";
}

function log(payload: Record<string, unknown>): void {
  console.log(JSON.stringify({
    worker: "referral-finance-scheduler",
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
    const url = env.SUPABASE_FUNCTION_URL;
    const secret = env.REFERRAL_WORKER_SECRET;

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
      status: response.status,
      gate_enabled: result.gate_enabled,
      selected_count: result.selected_count,
      processed_count: result.processed_count,
      failed_count: result.failed_count,
      duration_ms: Math.round(performance.now() - started),
    });
  },
};
