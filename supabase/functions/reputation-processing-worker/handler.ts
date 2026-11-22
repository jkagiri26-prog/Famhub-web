// ============================================================================
// Reputation Processing Worker — request handler and processing policy.
//
// Phase 2C-3 is the execution layer only. It claims work from the Phase 2C-2
// ledger, invokes the Phase 2C-1 ingestion gateway, and completes the work
// through the Phase 2C-2 completion gateway. It does not schedule itself.
// ============================================================================

export type WorkerEnv = {
  get(key: string): string | undefined;
};

export type RpcErrorLike = {
  code?: string | null;
  message?: string | null;
  name?: string | null;
  status?: number | null;
};

export type WorkerRpcResult = {
  data: unknown;
  error: RpcErrorLike | null;
};

export type WorkerConfig = {
  supabaseUrl: string;
  serviceRoleKey: string;
  workerSecret: string;
  workerId: string;
};

export type ClaimedWork = {
  workId: string;
  workKind: string;
  sourceSystem: string;
  sourceReference: string;
  attemptNumber: number;
  claimToken: string;
  leaseExpiresAt: string;
};

export type WorkerRpc = {
  claim(
    limit: number,
    workerId: string,
    leaseSeconds: number,
  ): Promise<WorkerRpcResult>;
  ingest(orderId: string): Promise<WorkerRpcResult>;
  captureEvidence(
    engagementId: string,
    requestId: string,
  ): Promise<WorkerRpcResult>;
  complete(
    workId: string,
    claimToken: string,
    outcome: string,
    errorCategory: string | null,
    errorCode: string | null,
    errorMessage: string | null,
    runId: string,
  ): Promise<WorkerRpcResult>;
};

export type WorkerRpcFactory = (config: WorkerConfig) => WorkerRpc;

export type WorkerOptions = {
  now?: () => number;
  overallBudgetMs?: number;
  perJobBudgetMs?: number;
  minJobStartBudgetMs?: number;
};

const DEFAULT_WORKER_ID = "reputation-processing-worker";
const MAX_BATCH = 5;
const DEFAULT_BATCH = 5;
const LEASE_SECONDS = 120;
const PER_JOB_BUDGET_MS = 8_000;
const OVERALL_BUDGET_MS = 45_000;
const MIN_JOB_START_BUDGET_MS = 8_000;
const JSON_HEADERS = { "Content-Type": "application/json; charset=utf-8" };

const EXPECTED_WORK_KIND = "stock_order_engagement_ingestion";
const EXPECTED_SOURCE_SYSTEM = "vunio";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const INGESTION_OUTCOMES = new Set([
  "created",
  "already_ingested",
  "repaired",
  "ineligible",
  "source_conflict",
]);

const EVIDENCE_OUTCOMES = new Set([
  "recorded",
  "already_recorded",
  "conflict_recorded",
]);

const EVIDENCE_STATUSES = new Set([
  "active",
  "revoked",
  "superseded",
  "conflicted",
]);

const COMPLETION_STATUSES = new Set([
  "succeeded",
  "retryable",
  "dead_letter",
]);

type CompletionStatus = "succeeded" | "retryable" | "dead_letter";

type CompletionAttempt =
  | { kind: "completed"; status: CompletionStatus }
  | { kind: "failed"; errorCode: string; errorCategory: string | null }
  | { kind: "systemic"; errorCode: string };

type JobResult =
  | { kind: "completed"; status: CompletionStatus }
  | { kind: "failed" }
  | { kind: "systemic" };

type IngestionResult = {
  outcome: string;
  reasonCode: string | null;
  engagementId: string | null;
};

type EvidenceResult = {
  outcome: string;
  evidenceStatus: string;
};

type EvidenceAttempt =
  | { kind: "success"; outcome: string; status: string }
  | { kind: "conflict"; outcome: string; status: string; errorCode: string }
  | { kind: "retryable"; errorCode: string }
  | { kind: "systemic"; errorCode: string };

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS,
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim() !== "";
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_RE.test(value);
}

function isPositiveInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value > 0;
}

function log(
  level: string,
  runId: string,
  payload: Record<string, unknown>,
): void {
  console.log(JSON.stringify({
    level,
    worker: "reputation-processing-worker",
    run_id: runId,
    ...payload,
  }));
}

function readConfiguration(
  env: WorkerEnv,
): { ok: true; config: WorkerConfig } | { ok: false } {
  const supabaseUrl = env.get("SUPABASE_URL")?.trim();
  const serviceRoleKey = env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  const workerSecret = env.get("REPUTATION_WORKER_SECRET");
  const configuredWorkerId = env.get("REPUTATION_WORKER_ID")?.trim();
  const workerId = configuredWorkerId || DEFAULT_WORKER_ID;

  if (!supabaseUrl || !serviceRoleKey || !workerSecret || !workerId) {
    return { ok: false };
  }
  if (workerId.length > 200) {
    return { ok: false };
  }

  return {
    ok: true,
    config: { supabaseUrl, serviceRoleKey, workerSecret, workerId },
  };
}

async function readLimit(req: Request): Promise<
  { ok: true; limit: number } | { ok: false }
> {
  let text: string;
  try {
    text = await req.text();
  } catch (_) {
    return { ok: false };
  }

  if (text.trim() === "") {
    return { ok: true, limit: DEFAULT_BATCH };
  }

  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch (_) {
    return { ok: false };
  }

  if (!isRecord(body)) {
    return { ok: false };
  }
  if (body.limit === undefined) {
    return { ok: true, limit: DEFAULT_BATCH };
  }
  if (
    typeof body.limit !== "number"
    || !Number.isInteger(body.limit)
    || body.limit < 1
  ) {
    return { ok: false };
  }

  return { ok: true, limit: Math.min(body.limit, MAX_BATCH) };
}

class RpcTimeoutError extends Error {
  constructor() {
    super("gateway_timeout");
    this.name = "TimeoutError";
  }
}

function withTimeout<T>(promise: Promise<T>, milliseconds: number): Promise<T> {
  const timeoutMs = Math.max(1, Math.floor(milliseconds));
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new RpcTimeoutError()), timeoutMs);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error) => {
        clearTimeout(timer);
        reject(error);
      },
    );
  });
}

function errorField(
  error: unknown,
  key: "code" | "name" | "message" | "status",
): unknown {
  return isRecord(error) ? error[key] : undefined;
}

function rpcErrorCode(error: unknown): string | null {
  const code = errorField(error, "code");
  return typeof code === "string" && code.trim() !== "" ? code : null;
}

function errorStatus(error: unknown): number | null {
  const status = errorField(error, "status");
  return typeof status === "number" && Number.isFinite(status) ? status : null;
}

function isTransientError(error: unknown): boolean {
  const code = rpcErrorCode(error);
  if (code) {
    if (code.startsWith("08")) return true;
    if (code === "40001" || code === "40P01" || code === "57014") return true;
    if (code === "PGRST000") return true;
  }

  const status = errorStatus(error);
  if (status === 429 || (status !== null && status >= 500 && status <= 599)) {
    return true;
  }

  const name = errorField(error, "name");
  if (name === "AbortError" || name === "TimeoutError") return true;

  if (name === "TypeError") {
    const message = errorField(error, "message");
    if (typeof message === "string") {
      const normalized = message.toLowerCase();
      return normalized.includes("fetch")
        || normalized.includes("network")
        || normalized.includes("connection");
    }
  }

  return false;
}

function transientErrorCode(error: unknown): string {
  const code = rpcErrorCode(error);
  if (code === "57014") return "gateway_cancelled";
  if (code === "40001") return "database_serialization_failure";
  if (code === "40P01") return "database_deadlock";
  if (code?.startsWith("08")) return "database_unavailable";

  const status = errorStatus(error);
  if (status === 429) return "gateway_rate_limited";
  if (status !== null && status >= 500 && status <= 599) {
    return "gateway_unavailable";
  }

  const name = errorField(error, "name");
  if (name === "AbortError" || name === "TimeoutError") {
    return "gateway_timeout";
  }

  return "gateway_unavailable";
}

function isStaleError(error: unknown): boolean {
  return rpcErrorCode(error) === "55000";
}

function isMissingOrderError(error: unknown): boolean {
  return rpcErrorCode(error) === "P0002";
}

function parseClaimRows(data: unknown, limit: number): ClaimedWork[] | null {
  if (!Array.isArray(data) || data.length > limit) return null;

  const rows: ClaimedWork[] = [];
  for (const value of data) {
    if (!isRecord(value)) return null;
    if (
      !isUuid(value.work_id)
      || !isNonEmptyString(value.work_kind)
      || !isNonEmptyString(value.source_system)
      || !isNonEmptyString(value.source_reference)
      || !isPositiveInteger(value.attempt_number)
      || !isUuid(value.claim_token)
      || !isNonEmptyString(value.lease_expires_at)
      || Number.isNaN(Date.parse(value.lease_expires_at as string))
    ) {
      return null;
    }

    rows.push({
      workId: value.work_id,
      workKind: value.work_kind,
      sourceSystem: value.source_system,
      sourceReference: value.source_reference,
      attemptNumber: value.attempt_number,
      claimToken: value.claim_token,
      leaseExpiresAt: value.lease_expires_at,
    });
  }

  return rows;
}

function parseIngestionResult(data: unknown): IngestionResult | null {
  if (!Array.isArray(data) || data.length !== 1) return null;
  const row = data[0];
  if (!isRecord(row) || !isNonEmptyString(row.outcome)) return null;
  if (!INGESTION_OUTCOMES.has(row.outcome)) return null;

  const reasonCode = isNonEmptyString(row.reason_code)
    ? row.reason_code
    : null;

  if (
    (row.outcome === "ineligible" || row.outcome === "source_conflict")
    && (!reasonCode || reasonCode.length > 100)
  ) {
    return null;
  }

  const successOutcome = row.outcome === "created"
    || row.outcome === "already_ingested"
    || row.outcome === "repaired";

  if (successOutcome && !isUuid(row.engagement_id)) {
    return null;
  }

  return {
    outcome: row.outcome,
    reasonCode,
    engagementId: successOutcome ? row.engagement_id as string : null,
  };
}

function parseEvidenceResult(data: unknown): EvidenceResult | null {
  if (!Array.isArray(data) || data.length !== 1) return null;
  const row = data[0];
  if (!isRecord(row) || !isNonEmptyString(row.outcome)) return null;
  if (!EVIDENCE_OUTCOMES.has(row.outcome)) return null;
  if (!isNonEmptyString(row.evidence_status)) return null;
  if (!EVIDENCE_STATUSES.has(row.evidence_status)) return null;
  return {
    outcome: row.outcome,
    evidenceStatus: row.evidence_status,
  };
}

function parseCompletionStatus(data: unknown): CompletionStatus | null {
  if (!Array.isArray(data) || data.length !== 1) return null;
  const row = data[0];
  if (!isRecord(row) || !isNonEmptyString(row.status)) return null;
  if (!COMPLETION_STATUSES.has(row.status)) return null;
  return row.status as CompletionStatus;
}

function expectedCompletionStatuses(outcome: string): CompletionStatus[] {
  if (outcome === "succeeded") return ["succeeded"];
  if (outcome === "retryable") return ["retryable", "dead_letter"];
  return ["dead_letter"];
}

function completionIsExpected(
  requestedOutcome: string,
  actualStatus: CompletionStatus,
): boolean {
  return expectedCompletionStatuses(requestedOutcome).includes(actualStatus);
}

function callBudget(
  now: () => number,
  overallStarted: number,
  jobStarted: number,
  options: Required<WorkerOptions>,
): number {
  const elapsedOverall = now() - overallStarted;
  const elapsedJob = now() - jobStarted;
  return Math.min(
    options.perJobBudgetMs - elapsedJob,
    options.overallBudgetMs - elapsedOverall,
  );
}

function logJob(
  runId: string,
  workerId: string,
  item: ClaimedWork,
  started: number,
  now: () => number,
  outcome: string,
  completionStatus: string | null,
  errorCategory: string | null,
  errorCode: string | null,
  evidence: (EvidenceResult & { engagementId: string }) | null = null,
): void {
  log("info", runId, {
    worker_id: workerId,
    work_id: item.workId,
    work_kind: item.workKind,
    source_reference: item.sourceReference,
    attempt_number: item.attemptNumber,
    outcome,
    completion_status: completionStatus,
    error_category: errorCategory,
    error_code: errorCode,
    engagement_id: evidence?.engagementId ?? null,
    evidence_outcome: evidence?.outcome ?? null,
    evidence_status: evidence?.evidenceStatus ?? null,
    duration_ms: Math.max(0, Math.round(now() - started)),
  });
}

async function completeWork(
  item: ClaimedWork,
  outcome: string,
  errorCategory: string | null,
  errorCode: string | null,
  errorMessage: string | null,
  runId: string,
  rpc: WorkerRpc,
  now: () => number,
  overallStarted: number,
  jobStarted: number,
  options: Required<WorkerOptions>,
): Promise<CompletionAttempt> {
  let result: WorkerRpcResult;
  try {
    result = await withTimeout(
      rpc.complete(
        item.workId,
        item.claimToken,
        outcome,
        errorCategory,
        errorCode,
        errorMessage,
        runId,
      ),
      callBudget(now, overallStarted, jobStarted, options),
    );
  } catch (error) {
    if (isStaleError(error)) {
      return { kind: "failed", errorCode: "stale_claim", errorCategory: null };
    }
    if (isTransientError(error)) {
      return {
        kind: "failed",
        errorCode: transientErrorCode(error),
        errorCategory: "transient_technical",
      };
    }
    return { kind: "systemic", errorCode: "completion_gateway_error" };
  }

  if (result.error) {
    if (isStaleError(result.error)) {
      return { kind: "failed", errorCode: "stale_claim", errorCategory: null };
    }
    if (isTransientError(result.error)) {
      return {
        kind: "failed",
        errorCode: transientErrorCode(result.error),
        errorCategory: "transient_technical",
      };
    }
    if (rpcErrorCode(result.error) === "P0002") {
      return { kind: "failed", errorCode: "work_not_found", errorCategory: null };
    }
    return { kind: "systemic", errorCode: "completion_gateway_error" };
  }

  const status = parseCompletionStatus(result.data);
  if (!status) {
    return { kind: "systemic", errorCode: "completion_contract_invalid" };
  }
  if (!completionIsExpected(outcome, status)) {
    return { kind: "systemic", errorCode: "completion_status_mismatch" };
  }

  return { kind: "completed", status };
}

async function captureEvidence(
  engagementId: string,
  runId: string,
  rpc: WorkerRpc,
  now: () => number,
  overallStarted: number,
  jobStarted: number,
  options: Required<WorkerOptions>,
): Promise<EvidenceAttempt> {
  let result: WorkerRpcResult;
  try {
    result = await withTimeout(
      rpc.captureEvidence(engagementId, runId),
      callBudget(now, overallStarted, jobStarted, options),
    );
  } catch (error) {
    if (isTransientError(error)) {
      return { kind: "retryable", errorCode: transientErrorCode(error) };
    }
    return { kind: "systemic", errorCode: "evidence_gateway_error" };
  }

  if (result.error) {
    if (isTransientError(result.error)) {
      return {
        kind: "retryable",
        errorCode: transientErrorCode(result.error),
      };
    }
    return { kind: "systemic", errorCode: "evidence_gateway_error" };
  }

  const parsed = parseEvidenceResult(result.data);
  if (!parsed) {
    return { kind: "systemic", errorCode: "evidence_contract_invalid" };
  }

  if (
    parsed.outcome === "conflict_recorded"
    || parsed.evidenceStatus === "conflicted"
  ) {
    return {
      kind: "conflict",
      outcome: parsed.outcome,
      status: parsed.evidenceStatus,
      errorCode: parsed.outcome === "already_recorded"
        ? "evidence_already_conflicted"
        : "evidence_conflict_recorded",
    };
  }

  if (
    parsed.outcome === "recorded"
    || parsed.outcome === "already_recorded"
  ) {
    return {
      kind: "success",
      outcome: parsed.outcome,
      status: parsed.evidenceStatus,
    };
  }

  return { kind: "systemic", errorCode: "evidence_contract_invalid" };
}

async function processItem(
  item: ClaimedWork,
  runId: string,
  workerId: string,
  rpc: WorkerRpc,
  now: () => number,
  overallStarted: number,
  options: Required<WorkerOptions>,
): Promise<JobResult> {
  const jobStarted = now();

  if (
    item.workKind !== EXPECTED_WORK_KIND
    || item.sourceSystem !== EXPECTED_SOURCE_SYSTEM
  ) {
    log("error", runId, {
      worker_id: workerId,
      work_id: item.workId,
      work_kind: item.workKind,
      source_system: item.sourceSystem,
      attempt_number: item.attemptNumber,
      outcome: "unsupported_work_identity",
      error_code: "unsupported_work_identity",
      duration_ms: Math.max(0, Math.round(now() - jobStarted)),
    });
    return { kind: "systemic" };
  }

  if (!isUuid(item.sourceReference)) {
    const completion = await completeWork(
      item,
      "dead_letter",
      "unexpected_permanent",
      "invalid_order_reference",
      "Invalid work source reference",
      runId,
      rpc,
      now,
      overallStarted,
      jobStarted,
      options,
    );

    if (completion.kind === "completed") {
      logJob(
        runId,
        workerId,
        item,
        jobStarted,
        now,
        "invalid_order_reference",
        completion.status,
        "unexpected_permanent",
        "invalid_order_reference",
      );
      return { kind: "completed", status: completion.status };
    }
    if (completion.kind === "failed") {
      logJob(
        runId,
        workerId,
        item,
        jobStarted,
        now,
        "invalid_order_reference",
        null,
        completion.errorCategory,
        completion.errorCode,
      );
      return { kind: "failed" };
    }
    return { kind: "systemic" };
  }

  let ingestion: WorkerRpcResult;
  try {
    ingestion = await withTimeout(
      rpc.ingest(item.sourceReference),
      callBudget(now, overallStarted, jobStarted, options),
    );
  } catch (error) {
    if (isTransientError(error)) {
      const code = transientErrorCode(error);
      const completion = await completeWork(
        item,
        "retryable",
        "transient_technical",
        code,
        "Transient ingestion gateway failure",
        runId,
        rpc,
        now,
        overallStarted,
        jobStarted,
        options,
      );

      if (completion.kind === "completed") {
        logJob(
          runId,
          workerId,
          item,
          jobStarted,
          now,
          "transient_ingestion_failure",
          completion.status,
          "transient_technical",
          code,
        );
        return { kind: "completed", status: completion.status };
      }
      if (completion.kind === "failed") {
        logJob(
          runId,
          workerId,
          item,
          jobStarted,
          now,
          "transient_ingestion_failure",
          null,
          completion.errorCategory,
          completion.errorCode,
        );
        return { kind: "failed" };
      }
      return { kind: "systemic" };
    }

    log("error", runId, {
      worker_id: workerId,
      work_id: item.workId,
      work_kind: item.workKind,
      source_reference: item.sourceReference,
      attempt_number: item.attemptNumber,
      outcome: "ingestion_transport_error",
      error_code: "ingestion_gateway_error",
      duration_ms: Math.max(0, Math.round(now() - jobStarted)),
    });
    return { kind: "systemic" };
  }

  if (ingestion.error) {
    if (isMissingOrderError(ingestion.error)) {
      const completion = await completeWork(
        item,
        "dead_letter",
        "ineligible_business",
        "commerce_order_not_found",
        "Source order was not found",
        runId,
        rpc,
        now,
        overallStarted,
        jobStarted,
        options,
      );

      if (completion.kind === "completed") {
        logJob(
          runId,
          workerId,
          item,
          jobStarted,
          now,
          "missing_commerce_order",
          completion.status,
          "ineligible_business",
          "commerce_order_not_found",
        );
        return { kind: "completed", status: completion.status };
      }
      if (completion.kind === "failed") {
        logJob(
          runId,
          workerId,
          item,
          jobStarted,
          now,
          "missing_commerce_order",
          null,
          completion.errorCategory,
          completion.errorCode,
        );
        return { kind: "failed" };
      }
      return { kind: "systemic" };
    }

    if (isTransientError(ingestion.error)) {
      const code = transientErrorCode(ingestion.error);
      const completion = await completeWork(
        item,
        "retryable",
        "transient_technical",
        code,
        "Transient ingestion gateway failure",
        runId,
        rpc,
        now,
        overallStarted,
        jobStarted,
        options,
      );

      if (completion.kind === "completed") {
        logJob(
          runId,
          workerId,
          item,
          jobStarted,
          now,
          "transient_ingestion_failure",
          completion.status,
          "transient_technical",
          code,
        );
        return { kind: "completed", status: completion.status };
      }
      if (completion.kind === "failed") {
        logJob(
          runId,
          workerId,
          item,
          jobStarted,
          now,
          "transient_ingestion_failure",
          null,
          completion.errorCategory,
          completion.errorCode,
        );
        return { kind: "failed" };
      }
      return { kind: "systemic" };
    }

    log("error", runId, {
      worker_id: workerId,
      work_id: item.workId,
      work_kind: item.workKind,
      source_reference: item.sourceReference,
      attempt_number: item.attemptNumber,
      outcome: "ingestion_gateway_error",
      error_code: rpcErrorCode(ingestion.error) ?? "ingestion_gateway_error",
      duration_ms: Math.max(0, Math.round(now() - jobStarted)),
    });
    return { kind: "systemic" };
  }

  const parsed = parseIngestionResult(ingestion.data);
  if (!parsed) {
    log("error", runId, {
      worker_id: workerId,
      work_id: item.workId,
      work_kind: item.workKind,
      source_reference: item.sourceReference,
      attempt_number: item.attemptNumber,
      outcome: "ingestion_contract_invalid",
      error_code: "ingestion_contract_invalid",
      duration_ms: Math.max(0, Math.round(now() - jobStarted)),
    });
    return { kind: "systemic" };
  }

  if (
    parsed.outcome === "created"
    || parsed.outcome === "already_ingested"
    || parsed.outcome === "repaired"
  ) {
    const engagementId = parsed.engagementId;
    if (!engagementId) {
      log("error", runId, {
        worker_id: workerId,
        work_id: item.workId,
        work_kind: item.workKind,
        source_reference: item.sourceReference,
        attempt_number: item.attemptNumber,
        outcome: "ingestion_contract_invalid",
        error_code: "ingestion_engagement_id_missing",
        duration_ms: Math.max(0, Math.round(now() - jobStarted)),
      });
      return { kind: "systemic" };
    }

    const evidence = await captureEvidence(
      engagementId,
      runId,
      rpc,
      now,
      overallStarted,
      jobStarted,
      options,
    );

    if (evidence.kind === "systemic") {
      log("error", runId, {
        worker_id: workerId,
        work_id: item.workId,
        work_kind: item.workKind,
        source_reference: item.sourceReference,
        engagement_id: engagementId,
        attempt_number: item.attemptNumber,
        outcome: "evidence_contract_invalid",
        error_code: evidence.errorCode,
        duration_ms: Math.max(0, Math.round(now() - jobStarted)),
      });
      return { kind: "systemic" };
    }

    if (evidence.kind === "retryable") {
      const completion = await completeWork(
        item,
        "retryable",
        "transient_technical",
        evidence.errorCode,
        "Transient evidence gateway failure",
        runId,
        rpc,
        now,
        overallStarted,
        jobStarted,
        options,
      );

      if (completion.kind === "completed") {
        logJob(
          runId,
          workerId,
          item,
          jobStarted,
          now,
          "transient_evidence_failure",
          completion.status,
          "transient_technical",
          evidence.errorCode,
        );
        return { kind: "completed", status: completion.status };
      }
      if (completion.kind === "failed") {
        logJob(
          runId,
          workerId,
          item,
          jobStarted,
          now,
          "transient_evidence_failure",
          null,
          completion.errorCategory,
          completion.errorCode,
        );
        return { kind: "failed" };
      }
      return { kind: "systemic" };
    }

    if (evidence.kind === "conflict") {
      const completion = await completeWork(
        item,
        "dead_letter",
        "source_conflict",
        evidence.errorCode,
        "Delivery evidence conflicts with existing Reputation state",
        runId,
        rpc,
        now,
        overallStarted,
        jobStarted,
        options,
      );

      if (completion.kind === "completed") {
        logJob(
          runId,
          workerId,
          item,
          jobStarted,
          now,
          parsed.outcome,
          completion.status,
          "source_conflict",
          evidence.errorCode,
          {
            engagementId,
            outcome: evidence.outcome,
            evidenceStatus: evidence.status,
          },
        );
        return { kind: "completed", status: completion.status };
      }
      if (completion.kind === "failed") {
        logJob(
          runId,
          workerId,
          item,
          jobStarted,
          now,
          parsed.outcome,
          null,
          completion.errorCategory,
          completion.errorCode,
          {
            engagementId,
            outcome: evidence.outcome,
            evidenceStatus: evidence.status,
          },
        );
        return { kind: "failed" };
      }
      return { kind: "systemic" };
    }

    const completion = await completeWork(
      item,
      "succeeded",
      null,
      null,
      null,
      runId,
      rpc,
      now,
      overallStarted,
      jobStarted,
      options,
    );

    if (completion.kind === "completed") {
      logJob(
        runId,
        workerId,
        item,
        jobStarted,
        now,
        parsed.outcome,
        completion.status,
        null,
        null,
        {
          engagementId,
          outcome: evidence.outcome,
          evidenceStatus: evidence.status,
        },
      );
      return { kind: "completed", status: completion.status };
    }
    if (completion.kind === "failed") {
      logJob(
        runId,
        workerId,
        item,
        jobStarted,
        now,
        parsed.outcome,
        null,
        completion.errorCategory,
        completion.errorCode,
        {
          engagementId,
          outcome: evidence.outcome,
          evidenceStatus: evidence.status,
        },
      );
      return { kind: "failed" };
    }
    return { kind: "systemic" };
  }

  const category = parsed.outcome === "ineligible"
    ? "ineligible_business"
    : "source_conflict";
  const message = parsed.outcome === "ineligible"
    ? "Source order is not eligible"
    : "Source order conflicts with existing Reputation state";
  const code = parsed.reasonCode as string;

  const completion = await completeWork(
    item,
    "dead_letter",
    category,
    code,
    message,
    runId,
    rpc,
    now,
    overallStarted,
    jobStarted,
    options,
  );

  if (completion.kind === "completed") {
    logJob(
      runId,
      workerId,
      item,
      jobStarted,
      now,
      parsed.outcome,
      completion.status,
      category,
      code,
    );
    return { kind: "completed", status: completion.status };
  }
  if (completion.kind === "failed") {
    logJob(
      runId,
      workerId,
      item,
      jobStarted,
      now,
      parsed.outcome,
      null,
      completion.errorCategory,
      completion.errorCode,
    );
    return { kind: "failed" };
  }
  return { kind: "systemic" };
}

export async function handleWorkerRequest(
  req: Request,
  env: WorkerEnv,
  createRpc: WorkerRpcFactory,
  options: WorkerOptions = {},
): Promise<Response> {
  const runId = crypto.randomUUID();
  const defaultNow = () => performance.now();
  const started = (options.now ?? defaultNow)();

  if (req.method !== "POST") {
    return json(405, { ok: false, error: "method_not_allowed", run_id: runId });
  }

  const configuration = readConfiguration(env);
  if (!configuration.ok) {
    log("error", runId, {
      outcome: "server_configuration_missing",
      error_code: "server_configuration_missing",
    });
    return json(500, {
      ok: false,
      error: "server_configuration_missing",
      run_id: runId,
    });
  }

  const config = configuration.config;
  if (req.headers.get("x-worker-secret") !== config.workerSecret) {
    log("warn", runId, {
      worker_id: config.workerId,
      outcome: "unauthorized",
    });
    return json(401, { ok: false, error: "unauthorized", run_id: runId });
  }

  const limitResult = await readLimit(req);
  if (!limitResult.ok) {
    return json(400, { ok: false, error: "invalid_request", run_id: runId });
  }

  let rpc: WorkerRpc;
  try {
    rpc = createRpc(config);
  } catch (_) {
    log("error", runId, {
      worker_id: config.workerId,
      outcome: "worker_rpc_initialization_failed",
      error_code: "worker_rpc_initialization_failed",
    });
    return json(500, {
      ok: false,
      error: "worker_rpc_initialization_failed",
      run_id: runId,
    });
  }

  const effectiveOptions: Required<WorkerOptions> = {
    now: options.now ?? (() => performance.now()),
    overallBudgetMs: options.overallBudgetMs ?? OVERALL_BUDGET_MS,
    perJobBudgetMs: options.perJobBudgetMs ?? PER_JOB_BUDGET_MS,
    minJobStartBudgetMs: options.minJobStartBudgetMs
      ?? MIN_JOB_START_BUDGET_MS,
  };

  let claimResult: WorkerRpcResult;
  try {
    claimResult = await withTimeout(
      rpc.claim(limitResult.limit, config.workerId, LEASE_SECONDS),
      effectiveOptions.overallBudgetMs,
    );
  } catch (_) {
    const durationMs = Math.max(0, Math.round(effectiveOptions.now() - started));
    log("error", runId, {
      worker_id: config.workerId,
      outcome: "claim_failed",
      error_code: "claim_gateway_error",
      duration_ms: durationMs,
    });
    return json(500, {
      ok: false,
      error: "worker_claim_failed",
      run_id: runId,
      worker_id: config.workerId,
      duration_ms: durationMs,
    });
  }

  if (claimResult.error) {
    const durationMs = Math.max(0, Math.round(effectiveOptions.now() - started));
    log("error", runId, {
      worker_id: config.workerId,
      outcome: "claim_failed",
      error_code: rpcErrorCode(claimResult.error) ?? "claim_gateway_error",
      duration_ms: durationMs,
    });
    return json(500, {
      ok: false,
      error: "worker_claim_failed",
      run_id: runId,
      worker_id: config.workerId,
      duration_ms: durationMs,
    });
  }

  const claimed = parseClaimRows(claimResult.data, limitResult.limit);
  if (!claimed) {
    const durationMs = Math.max(0, Math.round(effectiveOptions.now() - started));
    log("error", runId, {
      worker_id: config.workerId,
      outcome: "claim_contract_invalid",
      error_code: "claim_contract_invalid",
      duration_ms: durationMs,
    });
    return json(500, {
      ok: false,
      error: "worker_claim_invalid_response",
      run_id: runId,
      worker_id: config.workerId,
      duration_ms: durationMs,
    });
  }

  let succeeded = 0;
  let retryable = 0;
  let deadLettered = 0;
  let failed = 0;
  let processed = 0;
  let skipped = 0;
  let aborted = false;

  for (let index = 0; index < claimed.length; index += 1) {
    const item = claimed[index];
    const elapsedOverall = effectiveOptions.now() - started;
    const remainingOverall = effectiveOptions.overallBudgetMs - elapsedOverall;

    if (remainingOverall < effectiveOptions.minJobStartBudgetMs) {
      skipped = claimed.length - index;
      break;
    }

    processed += 1;
    const result = await processItem(
      item,
      runId,
      config.workerId,
      rpc,
      effectiveOptions.now,
      started,
      effectiveOptions,
    );

    if (result.kind === "completed") {
      if (result.status === "succeeded") succeeded += 1;
      else if (result.status === "retryable") retryable += 1;
      else deadLettered += 1;
      continue;
    }

    failed += 1;
    if (result.kind === "systemic") {
      skipped = claimed.length - index - 1;
      aborted = true;
      break;
    }
  }

  const durationMs = Math.max(0, Math.round(effectiveOptions.now() - started));
  const body: Record<string, unknown> = {
    ok: !aborted,
    run_id: runId,
    worker_id: config.workerId,
    claimed: claimed.length,
    succeeded,
    retryable,
    dead_lettered: deadLettered,
    failed,
    skipped,
    duration_ms: durationMs,
  };

  if (aborted) {
    log("error", runId, {
      worker_id: config.workerId,
      outcome: "invocation_aborted",
      claimed: claimed.length,
      processed,
      succeeded,
      retryable,
      failed,
      skipped,
      duration_ms: durationMs,
    });
    return json(500, {
      ...body,
      error: "worker_invocation_aborted",
    });
  }

  log("info", runId, {
    worker_id: config.workerId,
    outcome: "completed",
    claimed: claimed.length,
    processed,
    succeeded,
    retryable,
    dead_lettered: deadLettered,
    failed,
    skipped,
    duration_ms: durationMs,
  });

  return json(200, body);
}
