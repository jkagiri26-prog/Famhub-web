// ============================================================================
// Refer & Earn Finance Worker Request Handler — server-side logic
// ============================================================================

export type WorkerEnv = {
  get(key: string): string | undefined;
};

export type WorkerRpcResult = {
  data: unknown;
  error: { code?: string | null } | null;
};

export type WorkerRpc = (limit: number) => Promise<WorkerRpcResult>;

type WorkerResultRow = {
  gate_enabled: boolean;
  selected_count: number;
  processed_count: number;
  failed_count: number;
};

const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 100;
const JSON_HEADERS = { "Content-Type": "application/json; charset=utf-8" };

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS,
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseWorkerResult(data: unknown): WorkerResultRow | null {
  if (!Array.isArray(data) || data.length !== 1) return null;
  const row = data[0];
  if (!isRecord(row)) return null;
  if (typeof row.gate_enabled !== "boolean") return null;

  const counts = [row.selected_count, row.processed_count, row.failed_count];
  if (counts.some((value) => typeof value !== "number" || !Number.isInteger(value) || value < 0)) {
    return null;
  }

  return {
    gate_enabled: row.gate_enabled,
    selected_count: row.selected_count as number,
    processed_count: row.processed_count as number,
    failed_count: row.failed_count as number,
  };
}

function log(level: string, runId: string, payload: Record<string, unknown>): void {
  console.log(JSON.stringify({
    level,
    worker: "referral-finance-worker",
    run_id: runId,
    ...payload,
  }));
}

export async function handleWorkerRequest(
  req: Request,
  env: WorkerEnv,
  rpc: WorkerRpc,
): Promise<Response> {
  const runId = crypto.randomUUID();
  const started = performance.now();

  if (req.method !== "POST") {
    return json(405, { ok: false, error: "method_not_allowed" });
  }

  const expectedSecret = env.get("REFERRAL_WORKER_SECRET");
  if (!expectedSecret || req.headers.get("x-worker-secret") !== expectedSecret) {
    log("warn", runId, { outcome: "unauthorized" });
    return json(401, { ok: false, error: "unauthorized" });
  }

  const supabaseUrl = env.get("SUPABASE_URL");
  const serviceRoleKey = env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    log("error", runId, { outcome: "missing_server_credentials" });
    return json(500, { ok: false, error: "server_configuration_missing" });
  }

  let limit = DEFAULT_LIMIT;
  try {
    const body = await req.json().catch(() => ({}));
    if (typeof body?.limit === "number" && Number.isFinite(body.limit)) {
      limit = Math.max(1, Math.min(MAX_LIMIT, Math.trunc(body.limit)));
    }
  } catch (_) {
    return json(400, { ok: false, error: "invalid_json" });
  }

  let rpcResult: WorkerRpcResult;
  try {
    rpcResult = await rpc(limit);
  } catch (_) {
    const durationMs = Math.round(performance.now() - started);
    log("error", runId, {
      outcome: "rpc_error",
      limit,
      duration_ms: durationMs,
      error_code: null,
    });
    return json(500, { ok: false, error: "worker_rpc_failed", run_id: runId });
  }

  const durationMs = Math.round(performance.now() - started);
  const { data, error } = rpcResult;

  if (error) {
    log("error", runId, {
      outcome: "rpc_error",
      limit,
      duration_ms: durationMs,
      error_code: error.code ?? null,
    });
    return json(500, { ok: false, error: "worker_rpc_failed", run_id: runId });
  }

  const row = parseWorkerResult(data);
  if (!row) {
    log("error", runId, {
      outcome: "rpc_invalid_response",
      limit,
      duration_ms: durationMs,
    });
    return json(500, { ok: false, error: "worker_rpc_invalid_response", run_id: runId });
  }

  log("info", runId, {
    outcome: "completed",
    limit,
    gate_enabled: row.gate_enabled,
    selected_count: row.selected_count,
    processed_count: row.processed_count,
    failed_count: row.failed_count,
    duration_ms: durationMs,
  });

  return json(200, {
    ok: true,
    run_id: runId,
    gate_enabled: row.gate_enabled,
    selected_count: row.selected_count,
    processed_count: row.processed_count,
    failed_count: row.failed_count,
  });
}
