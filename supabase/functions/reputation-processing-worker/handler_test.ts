import {
  assert,
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  handleWorkerRequest,
  type ClaimedWork,
  type WorkerEnv,
  type WorkerOptions,
  type WorkerRpc,
  type WorkerRpcResult,
} from "./handler.ts";

const WORKER_SECRET = "worker-secret-test";
const SERVICE_ROLE_KEY = "service-role-test";
const CLAIM_TOKEN = "30000000-0000-4000-8000-000000000001";
const WORK_ID = "10000000-0000-4000-8000-000000000001";

type CompleteCall = {
  workId: string;
  claimToken: string;
  outcome: string;
  errorCategory: string | null;
  errorCode: string | null;
  errorMessage: string | null;
  runId: string;
};

type Calls = {
  claim: Array<{ limit: number; workerId: string; leaseSeconds: number }>;
  ingest: string[];
  complete: CompleteCall[];
};

type RpcOverrides = {
  claim?: (
    limit: number,
    workerId: string,
    leaseSeconds: number,
  ) => Promise<WorkerRpcResult>;
  ingest?: (orderId: string) => Promise<WorkerRpcResult>;
  complete?: (
    workId: string,
    claimToken: string,
    outcome: string,
    errorCategory: string | null,
    errorCode: string | null,
    errorMessage: string | null,
    runId: string,
  ) => Promise<WorkerRpcResult>;
};

function baseEnv(overrides: Record<string, string | undefined> = {}): WorkerEnv {
  const values: Record<string, string | undefined> = {
    SUPABASE_URL: "http://local",
    SUPABASE_SERVICE_ROLE_KEY: SERVICE_ROLE_KEY,
    REPUTATION_WORKER_SECRET: WORKER_SECRET,
    REPUTATION_WORKER_ID: "test-worker",
    ...overrides,
  };
  return { get: (key) => values[key] };
}

function request(
  method = "POST",
  body?: unknown,
  secret: string | null = WORKER_SECRET,
): Request {
  const headers = new Headers();
  if (secret !== null) headers.set("x-worker-secret", secret);
  if (body !== undefined) headers.set("content-type", "application/json");

  return new Request("http://worker.local", {
    method,
    headers,
    body: body === undefined
      ? undefined
      : typeof body === "string"
      ? body
      : JSON.stringify(body),
  });
}

function uuidSuffix(index: number): string {
  return String(index).padStart(12, "0");
}

function claimRow(index = 1, overrides: Partial<ClaimedWork> = {}): ClaimedWork {
  const suffix = uuidSuffix(index);
  return {
    workId: `10000000-0000-4000-8000-${suffix}`,
    workKind: "stock_order_engagement_ingestion",
    sourceSystem: "vunio",
    sourceReference: `20000000-0000-4000-8000-${suffix}`,
    attemptNumber: 1,
    claimToken: `30000000-0000-4000-8000-${suffix}`,
    leaseExpiresAt: "2026-11-21T12:00:00.000Z",
    ...overrides,
  };
}

function claimResponse(rows: ClaimedWork[]): WorkerRpcResult {
  return {
    data: rows.map((row) => ({
      work_id: row.workId,
      work_kind: row.workKind,
      source_system: row.sourceSystem,
      source_reference: row.sourceReference,
      attempt_number: row.attemptNumber,
      claim_token: row.claimToken,
      lease_expires_at: row.leaseExpiresAt,
    })),
    error: null,
  };
}

function ingestionSuccess(outcome = "created", reasonCode: string | null = null): WorkerRpcResult {
  return { data: [{ outcome, reason_code: reasonCode }], error: null };
}

function completionSuccess(status = "succeeded"): WorkerRpcResult {
  return {
    data: [{
      work_id: WORK_ID,
      status,
      attempt_count: 1,
      next_attempt_at: "2026-11-21T12:00:00.000Z",
    }],
    error: null,
  };
}

function rpcHarness(overrides: RpcOverrides = {}): {
  rpc: WorkerRpc;
  calls: Calls;
} {
  const calls: Calls = { claim: [], ingest: [], complete: [] };

  const rpc: WorkerRpc = {
    claim(limit, workerId, leaseSeconds) {
      calls.claim.push({ limit, workerId, leaseSeconds });
      return overrides.claim?.(limit, workerId, leaseSeconds)
        ?? Promise.resolve(claimResponse([]));
    },
    ingest(orderId) {
      calls.ingest.push(orderId);
      return overrides.ingest?.(orderId)
        ?? Promise.resolve(ingestionSuccess());
    },
    complete(
      workId,
      claimToken,
      outcome,
      errorCategory,
      errorCode,
      errorMessage,
      runId,
    ) {
      calls.complete.push({
        workId,
        claimToken,
        outcome,
        errorCategory,
        errorCode,
        errorMessage,
        runId,
      });
      return overrides.complete?.(
        workId,
        claimToken,
        outcome,
        errorCategory,
        errorCode,
        errorMessage,
        runId,
      ) ?? Promise.resolve(completionSuccess(
        outcome === "succeeded"
          ? "succeeded"
          : outcome === "retryable"
          ? "retryable"
          : "dead_letter",
      ));
    },
  };

  return { rpc, calls };
}

async function runWorker(
  req: Request,
  rpc: WorkerRpc,
  options: WorkerOptions = {},
  env: WorkerEnv = baseEnv(),
): Promise<Response> {
  return await handleWorkerRequest(req, env, () => rpc, options);
}

Deno.test("rejects non-POST and OPTIONS requests without claiming", async () => {
  for (const method of ["GET", "PUT", "PATCH", "DELETE", "OPTIONS"]) {
    const { rpc, calls } = rpcHarness();
    const response = await runWorker(request(method), rpc);
    assertEquals(response.status, 405, method);
    assertEquals(calls.claim.length, 0, method);
    const body = await response.json();
    assertEquals(body.error, "method_not_allowed");
  }
});

Deno.test("rejects missing and wrong worker secret without claiming", async () => {
  for (const secret of [null, "wrong-secret"]) {
    const { rpc, calls } = rpcHarness();
    const response = await runWorker(request("POST", undefined, secret), rpc);
    assertEquals(response.status, 401);
    assertEquals(calls.claim.length, 0);
  }
});

Deno.test("fails before claim when required configuration is missing", async () => {
  for (const missing of ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "REPUTATION_WORKER_SECRET"]) {
    const { rpc, calls } = rpcHarness();
    const response = await runWorker(
      request(),
      rpc,
      {},
      baseEnv({ [missing]: undefined }),
    );
    assertEquals(response.status, 500, missing);
    assertEquals(calls.claim.length, 0, missing);
    const body = await response.json();
    assertEquals(body.error, "server_configuration_missing");
  }
});

Deno.test("valid secret reaches claim and empty queue is a no-op", async () => {
  const { rpc, calls } = rpcHarness();
  const response = await runWorker(request(), rpc);
  assertEquals(response.status, 200);
  assertEquals(calls.claim.length, 1);
  assertEquals(calls.claim[0].limit, 5);
  assertEquals(calls.claim[0].workerId, "test-worker");
  assertEquals(calls.claim[0].leaseSeconds, 120);
  assertEquals(calls.ingest.length, 0);
  assertEquals(calls.complete.length, 0);

  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.claimed, 0);
  assertEquals(body.succeeded, 0);
  assertEquals(body.retryable, 0);
  assertEquals(body.dead_lettered, 0);
  assertEquals(body.failed, 0);
  assert(typeof body.run_id === "string" && body.run_id.length > 0);
  assertEquals(body.worker_id, "test-worker");
});

Deno.test("request body limit rules", async () => {
  const cases: Array<{ body: unknown; expected: number }> = [
    { body: undefined, expected: 5 },
    { body: {}, expected: 5 },
    { body: { limit: 1 }, expected: 1 },
    { body: { limit: 5 }, expected: 5 },
    { body: { limit: 6 }, expected: 5 },
    { body: { limit: 99 }, expected: 5 },
  ];

  for (const testCase of cases) {
    const { rpc, calls } = rpcHarness();
    const response = await runWorker(request("POST", testCase.body), rpc);
    assertEquals(response.status, 200);
    assertEquals(calls.claim[0].limit, testCase.expected);
  }

  const invalidBodies: unknown[] = [
    { limit: 0 },
    { limit: -1 },
    { limit: 1.5 },
    { limit: "5" },
    { limit: null },
    { limit: true },
    [],
    "not-json",
  ];

  for (const body of invalidBodies) {
    const { rpc, calls } = rpcHarness();
    const response = await runWorker(request("POST", body), rpc);
    assertEquals(response.status, 400);
    assertEquals(calls.claim.length, 0);
  }
});

Deno.test("successful ingestion outcomes complete as succeeded", async (t) => {
  for (const outcome of ["created", "already_ingested", "repaired"]) {
    await t.step(outcome, async () => {
      const row = claimRow(1);
      const { rpc, calls } = rpcHarness({
        claim: () => Promise.resolve(claimResponse([row])),
        ingest: () => Promise.resolve(ingestionSuccess(outcome)),
      });

      const response = await runWorker(request(), rpc);
      assertEquals(response.status, 200);
      assertEquals(calls.ingest, [row.sourceReference]);
      assertEquals(calls.complete.length, 1);
      assertEquals(calls.complete[0].workId, row.workId);
      assertEquals(calls.complete[0].claimToken, row.claimToken);
      assertEquals(calls.complete[0].outcome, "succeeded");
      assertEquals(calls.complete[0].errorCategory, null);
      assertEquals(calls.complete[0].errorCode, null);
      assertEquals(calls.complete[0].errorMessage, null);
      assert(calls.complete[0].runId.length > 0);

      const body = await response.json();
      assertEquals(body.succeeded, 1);
      assertEquals(body.failed, 0);
    });
  }
});

Deno.test("ineligible and source-conflict outcomes complete as dead_letter", async (t) => {
  for (
    const testCase of [
      {
        outcome: "ineligible",
        reason: "not_delivered",
        category: "ineligible_business",
      },
      {
        outcome: "source_conflict",
        reason: "source_event_conflict",
        category: "source_conflict",
      },
    ]
  ) {
    await t.step(testCase.outcome, async () => {
      const row = claimRow(1);
      const { rpc, calls } = rpcHarness({
        claim: () => Promise.resolve(claimResponse([row])),
        ingest: () => Promise.resolve(
          ingestionSuccess(testCase.outcome, testCase.reason),
        ),
      });

      const response = await runWorker(request(), rpc);
      assertEquals(response.status, 200);
      assertEquals(calls.complete.length, 1);
      assertEquals(calls.complete[0].outcome, "dead_letter");
      assertEquals(calls.complete[0].errorCategory, testCase.category);
      assertEquals(calls.complete[0].errorCode, testCase.reason);
      assertEquals(calls.complete[0].errorMessage?.length! <= 1000, true);

      const body = await response.json();
      assertEquals(body.dead_lettered, 1);
      assertEquals(body.failed, 0);
    });
  }
});

Deno.test("missing Commerce order completes as ineligible dead_letter", async () => {
  const row = claimRow(1);
  const { rpc, calls } = rpcHarness({
    claim: () => Promise.resolve(claimResponse([row])),
    ingest: () => Promise.resolve({
      data: null,
      error: { code: "P0002", message: "Commerce order not found" },
    }),
  });

  const response = await runWorker(request(), rpc);
  assertEquals(response.status, 200);
  assertEquals(calls.complete.length, 1);
  assertEquals(calls.complete[0].outcome, "dead_letter");
  assertEquals(calls.complete[0].errorCategory, "ineligible_business");
  assertEquals(calls.complete[0].errorCode, "commerce_order_not_found");
  assertFalse(calls.complete[0].errorMessage?.includes("Commerce order not found") ?? false);

  const body = await response.json();
  assertEquals(body.dead_lettered, 1);
  assertEquals(body.retryable, 0);
});

Deno.test("transient ingestion failures complete as retryable", async (t) => {
  const cases = [
    {
      name: "database serialization",
      error: { code: "40001", message: "serialization failure" },
      code: "database_serialization_failure",
    },
    {
      name: "network timeout",
      error: new DOMException("timed out", "TimeoutError"),
      code: "gateway_timeout",
    },
  ];

  for (const testCase of cases) {
    await t.step(testCase.name, async () => {
      const row = claimRow(1);
      const { rpc, calls } = rpcHarness({
        claim: () => Promise.resolve(claimResponse([row])),
        ingest: () => Promise.resolve({
          data: null,
          error: testCase.error as { code?: string; message?: string },
        }),
      });

      const response = await runWorker(request(), rpc);
      assertEquals(response.status, 200);
      assertEquals(calls.complete.length, 1);
      assertEquals(calls.complete[0].outcome, "retryable");
      assertEquals(calls.complete[0].errorCategory, "transient_technical");
      assertEquals(calls.complete[0].errorCode, testCase.code);

      const body = await response.json();
      assertEquals(body.retryable, 1);
      assertEquals(body.failed, 0);
    });
  }
});

Deno.test("invalid source reference completes as unexpected permanent dead_letter", async () => {
  const row = claimRow(1, { sourceReference: "not-a-uuid" });
  const { rpc, calls } = rpcHarness({
    claim: () => Promise.resolve(claimResponse([row])),
  });

  const response = await runWorker(request(), rpc);
  assertEquals(response.status, 200);
  assertEquals(calls.ingest.length, 0);
  assertEquals(calls.complete.length, 1);
  assertEquals(calls.complete[0].outcome, "dead_letter");
  assertEquals(calls.complete[0].errorCategory, "unexpected_permanent");
  assertEquals(calls.complete[0].errorCode, "invalid_order_reference");

  const body = await response.json();
  assertEquals(body.dead_lettered, 1);
});

Deno.test("stale completion does not retry or block other work", async () => {
  const first = claimRow(1);
  const second = claimRow(2);
  const { rpc, calls } = rpcHarness({
    claim: () => Promise.resolve(claimResponse([first, second])),
    complete: (workId, _claimToken, outcome) => {
      if (workId === first.workId) {
        return Promise.resolve({
          data: null,
          error: { code: "55000", message: "stale claim" },
        });
      }
      return Promise.resolve(completionSuccess(
        outcome === "succeeded" ? "succeeded" : "dead_letter",
      ));
    },
  });

  const response = await runWorker(request(), rpc);
  assertEquals(response.status, 200);
  assertEquals(calls.complete.length, 2);
  assertEquals(calls.complete.filter((call) => call.workId === first.workId).length, 1);
  assertEquals(calls.complete.filter((call) => call.workId === second.workId).length, 1);
  assertEquals(calls.ingest.length, 2);

  const body = await response.json();
  assertEquals(body.succeeded, 1);
  assertEquals(body.failed, 1);
  assertEquals(body.skipped, 0);
});

Deno.test("malformed ingestion response stops safely without completion", async () => {
  const first = claimRow(1);
  const second = claimRow(2);
  const { rpc, calls } = rpcHarness({
    claim: () => Promise.resolve(claimResponse([first, second])),
    ingest: () => Promise.resolve({
      data: { outcome: "created" },
      error: null,
    }),
  });

  const response = await runWorker(request(), rpc);
  assertEquals(response.status, 500);
  assertEquals(calls.ingest.length, 1);
  assertEquals(calls.complete.length, 0);

  const body = await response.json();
  assertEquals(body.ok, false);
  assertEquals(body.error, "worker_invocation_aborted");
  assertEquals(body.claimed, 2);
  assertEquals(body.failed, 1);
  assertEquals(body.skipped, 1);
});

Deno.test("unsupported work identity stops without ingestion or completion", async () => {
  const row = claimRow(1, { workKind: "unknown_work" });
  const { rpc, calls } = rpcHarness({
    claim: () => Promise.resolve(claimResponse([row])),
  });

  const response = await runWorker(request(), rpc);
  assertEquals(response.status, 500);
  assertEquals(calls.ingest.length, 0);
  assertEquals(calls.complete.length, 0);

  const body = await response.json();
  assertEquals(body.failed, 1);
  assertEquals(body.skipped, 0);
});

Deno.test("one job failure does not abort other claimed work", async () => {
  const rows = [1, 2, 3, 4, 5].map((index) => claimRow(index));
  const { rpc, calls } = rpcHarness({
    claim: () => Promise.resolve(claimResponse(rows)),
    ingest: (orderId) => {
      if (orderId === rows[1].sourceReference) {
        return Promise.resolve({
          data: null,
          error: { code: "40001", message: "serialization failure" },
        });
      }
      return Promise.resolve(ingestionSuccess());
    },
  });

  const response = await runWorker(request(), rpc);
  assertEquals(response.status, 200);
  assertEquals(calls.ingest.length, 5);
  assertEquals(calls.complete.length, 5);

  const body = await response.json();
  assertEquals(body.claimed, 5);
  assertEquals(body.succeeded, 4);
  assertEquals(body.retryable, 1);
  assertEquals(body.failed, 0);
  assertEquals(body.skipped, 0);
});

Deno.test("worker stops starting jobs near the invocation deadline", async () => {
  const rows = [1, 2, 3, 4, 5].map((index) => claimRow(index));
  const { rpc, calls } = rpcHarness({
    claim: () => Promise.resolve(claimResponse(rows)),
  });

  let clock = 0;
  const options: WorkerOptions = {
    now: () => {
      clock += 10;
      return clock;
    },
    overallBudgetMs: 45,
    perJobBudgetMs: 1_000,
    minJobStartBudgetMs: 10,
  };

  const response = await runWorker(request(), rpc, options);
  assertEquals(response.status, 200);
  assert(calls.ingest.length > 0);
  assert(calls.ingest.length < rows.length);
  assert(calls.complete.length < rows.length);

  const body = await response.json();
  assertEquals(body.claimed, 5);
  assert(body.skipped > 0);
  assertEquals(body.skipped + calls.ingest.length, 5);
});

Deno.test("uses a stable default worker id when not configured", async () => {
  const { rpc, calls } = rpcHarness();
  const response = await runWorker(
    request(),
    rpc,
    {},
    baseEnv({ REPUTATION_WORKER_ID: undefined }),
  );

  assertEquals(response.status, 200);
  assertEquals(calls.claim[0].workerId, "reputation-processing-worker");
  const body = await response.json();
  assertEquals(body.worker_id, "reputation-processing-worker");
});

Deno.test("ingestion timeout becomes retryable without local retry", async () => {
  const row = claimRow(1);
  let resolveIngest!: (value: WorkerRpcResult) => void;
  const pendingIngest = new Promise<WorkerRpcResult>((resolve) => {
    resolveIngest = resolve;
  });

  const { rpc, calls } = rpcHarness({
    claim: () => Promise.resolve(claimResponse([row])),
    ingest: () => pendingIngest,
  });

  try {
    const response = await runWorker(request(), rpc, {
      perJobBudgetMs: 10,
      overallBudgetMs: 1_000,
      minJobStartBudgetMs: 10,
    });

    assertEquals(response.status, 200);
    assertEquals(calls.ingest.length, 1);
    assertEquals(calls.complete.length, 1);
    assertEquals(calls.complete[0].outcome, "retryable");
    assertEquals(calls.complete[0].errorCategory, "transient_technical");
    assertEquals(calls.complete[0].errorCode, "gateway_timeout");

    const body = await response.json();
    assertEquals(body.retryable, 1);
    assertEquals(body.failed, 0);
  } finally {
    resolveIngest({ data: null, error: null });
  }
});

Deno.test("logs redact secrets and claim tokens", async () => {
  const row = claimRow(1);
  const { rpc } = rpcHarness({
    claim: () => Promise.resolve(claimResponse([row])),
  });

  const originalLog = console.log;
  const lines: string[] = [];
  console.log = (...args: unknown[]) => {
    lines.push(args.map((value) => String(value)).join(" "));
  };

  try {
    const response = await runWorker(request(), rpc);
    assertEquals(response.status, 200);
  } finally {
    console.log = originalLog;
  }

  const output = lines.join("\n");
  assert(output.length > 0);
  assertFalse(output.includes(WORKER_SECRET));
  assertFalse(output.includes(SERVICE_ROLE_KEY));
  assertFalse(output.includes(row.claimToken));
  assertFalse(output.includes(CLAIM_TOKEN));
  assert(output.includes(row.workId));
  assert(output.includes(row.sourceReference));
});
