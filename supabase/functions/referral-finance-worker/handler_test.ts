import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleWorkerRequest, type WorkerEnv, type WorkerRpcResult } from "./handler.ts";

function env(values: Record<string, string>): WorkerEnv {
  return { get: (key) => values[key] };
}

function req(secret?: string, authorization?: string): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (secret) headers["x-worker-secret"] = secret;
  if (authorization) headers.authorization = authorization;
  return new Request("http://localhost", {
    method: "POST",
    headers,
    body: JSON.stringify({ limit: 2 }),
  });
}

Deno.test("worker rejects missing and wrong secret", async () => {
  const config = env({
    SUPABASE_URL: "http://test",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-test",
    REFERRAL_WORKER_SECRET: "expected",
  });
  const noSecret = await handleWorkerRequest(req(), config, async () => ({
    data: null,
    error: null,
  }));
  assertEquals(noSecret.status, 401);
  const wrong = await handleWorkerRequest(req("wrong"), config, async () => ({
    data: null,
    error: null,
  }));
  assertEquals(wrong.status, 401);
});

Deno.test("worker accepts the worker secret without a JWT", async () => {
  const config = env({
    SUPABASE_URL: "http://test",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-test",
    REFERRAL_WORKER_SECRET: "expected",
  });
  const response = await handleWorkerRequest(req("expected"), config, async () => ({
    data: [{ gate_enabled: false, selected_count: 0, processed_count: 0, failed_count: 0 }],
    error: null,
  }));
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(JSON.stringify(body).includes("service-role-test"), false);
});

Deno.test("worker does not accept a JWT as the worker credential", async () => {
  const config = env({
    SUPABASE_URL: "http://test",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-test",
    REFERRAL_WORKER_SECRET: "expected",
  });
  const response = await handleWorkerRequest(
    req(undefined, "Bearer user-jwt"),
    config,
    async () => ({ data: null, error: null }),
  );
  assertEquals(response.status, 401);
});

Deno.test("worker fails safely when service configuration is missing", async () => {
  const config = env({ REFERRAL_WORKER_SECRET: "expected" });
  const response = await handleWorkerRequest(req("expected"), config, async () => ({
    data: null,
    error: null,
  }));
  assertEquals(response.status, 500);
  const body = await response.json();
  assertEquals(body.error, "server_configuration_missing");
  assertEquals(JSON.stringify(body).includes("service-role-test"), false);
});

Deno.test("worker no-ops when gate is disabled", async () => {
  const config = env({
    SUPABASE_URL: "http://test",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-test",
    REFERRAL_WORKER_SECRET: "expected",
  });
  const response = await handleWorkerRequest(req("expected"), config, async () => ({
    data: [{ gate_enabled: false, selected_count: 0, processed_count: 0, failed_count: 0 }],
    error: null,
  }));
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.gate_enabled, false);
  assertEquals(JSON.stringify(body).includes("service-role-test"), false);
});

Deno.test("worker returns generic error without leaking RPC details", async () => {
  const config = env({
    SUPABASE_URL: "http://test",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-test",
    REFERRAL_WORKER_SECRET: "expected",
  });
  const response = await handleWorkerRequest(req("expected"), config, async () => ({
    data: null,
    error: { code: "XX000" },
  }));
  assertEquals(response.status, 500);
  const body = await response.json();
  assertEquals(body.error, "worker_rpc_failed");
  assertEquals(JSON.stringify(body).includes("service-role-test"), false);
});

function validRow() {
  return {
    gate_enabled: false,
    selected_count: 1,
    processed_count: 1,
    failed_count: 0,
  };
}

function validConfig(): WorkerEnv {
  return env({
    SUPABASE_URL: "http://test",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-test",
    REFERRAL_WORKER_SECRET: "expected",
  });
}

Deno.test("worker rejects null RPC data", async () => {
  const response = await handleWorkerRequest(
    req("expected"),
    validConfig(),
    async () => ({ data: null, error: null }),
  );
  assertEquals(response.status, 500);
  const body = await response.json();
  assertEquals(body.error, "worker_rpc_invalid_response");
  assertEquals(JSON.stringify(body).includes("service-role-test"), false);
});

Deno.test("worker rejects an empty RPC result array", async () => {
  const response = await handleWorkerRequest(
    req("expected"),
    validConfig(),
    async () => ({ data: [], error: null }),
  );
  assertEquals(response.status, 500);
  const body = await response.json();
  assertEquals(body.error, "worker_rpc_invalid_response");
});

Deno.test("worker rejects multiple RPC result rows", async () => {
  const response = await handleWorkerRequest(
    req("expected"),
    validConfig(),
    async () => ({ data: [validRow(), validRow()], error: null }),
  );
  assertEquals(response.status, 500);
  const body = await response.json();
  assertEquals(body.error, "worker_rpc_invalid_response");
});

Deno.test("worker rejects malformed or incomplete RPC result rows", async () => {
  const invalidRows = [
    ["not an object"],
    [{ gate_enabled: "false", selected_count: 0, processed_count: 0, failed_count: 0 }],
    [{ gate_enabled: false, selected_count: 1.5, processed_count: 0, failed_count: 0 }],
    [{ gate_enabled: false, selected_count: 0, processed_count: -1, failed_count: 0 }],
    [{ gate_enabled: false, selected_count: 0, processed_count: 0 }],
  ];

  for (const data of invalidRows) {
    const response = await handleWorkerRequest(
      req("expected"),
      validConfig(),
      async () => ({ data, error: null }),
    );
    assertEquals(response.status, 500);
    const body = await response.json();
    assertEquals(body.error, "worker_rpc_invalid_response");
  }
});

Deno.test("worker returns a valid RPC result unchanged", async () => {
  const response = await handleWorkerRequest(
    req("expected"),
    validConfig(),
    async () => ({ data: [validRow()], error: null }),
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.gate_enabled, false);
  assertEquals(body.selected_count, 1);
  assertEquals(body.processed_count, 1);
  assertEquals(body.failed_count, 0);
});

Deno.test("worker waits for the RPC promise before responding", async () => {
  let resolveRpc!: (result: WorkerRpcResult) => void;
  let markRpcStarted!: () => void;
  const rpcStarted = new Promise<void>((resolve) => {
    markRpcStarted = resolve;
  });

  const rpc = (_limit: number): Promise<WorkerRpcResult> => {
    markRpcStarted();
    return new Promise<WorkerRpcResult>((resolve) => {
      resolveRpc = resolve;
    });
  };

  let responseSettled = false;
  const responsePromise = handleWorkerRequest(req("expected"), validConfig(), rpc)
    .then((response) => {
      responseSettled = true;
      return response;
    });

  await rpcStarted;
  await Promise.resolve();
  assertEquals(responseSettled, false);

  resolveRpc({ data: [validRow()], error: null });
  const response = await responsePromise;
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.ok, true);
});

Deno.test("worker returns a generic error when the RPC promise rejects", async () => {
  const response = await handleWorkerRequest(
    req("expected"),
    validConfig(),
    () => Promise.reject(new Error("rpc rejected")),
  );
  assertEquals(response.status, 500);
  const body = await response.json();
  assertEquals(body.error, "worker_rpc_failed");
  assertEquals(JSON.stringify(body).includes("rpc rejected"), false);
  assertEquals(JSON.stringify(body).includes("service-role-test"), false);
});
