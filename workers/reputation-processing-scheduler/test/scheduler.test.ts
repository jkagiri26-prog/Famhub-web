import { assertEquals, assertFalse } from "https://deno.land/std@0.224.0/assert/mod.ts";
import worker from "../src/index.ts";

const FUNCTION_URL =
  "https://staging.example.invalid/functions/v1/reputation-processing-worker";
const TEST_SECRET = "unit-test-secret-not-real";
const TEST_CLAIM_TOKEN = "claim-token-never-log";

type WorkerEnv = {
  REPUTATION_FUNCTION_URL?: string;
  REPUTATION_WORKER_SECRET?: string;
};

type FetchCall = {
  input: unknown;
  init?: RequestInit;
};

const validEnv: WorkerEnv = {
  REPUTATION_FUNCTION_URL: FUNCTION_URL,
  REPUTATION_WORKER_SECRET: TEST_SECRET,
};

const controller = {
  scheduledTime: Date.now(),
  cron: "*/5 * * * *",
};

const ctx = {
  waitUntil(_promise: Promise<unknown>): void {},
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function validBody(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    ok: true,
    run_id: "run-test",
    worker_id: "reputation-processing-worker",
    claimed: 2,
    succeeded: 1,
    retryable: 0,
    dead_lettered: 1,
    failed: 0,
    skipped: 0,
    duration_ms: 42,
    ...overrides,
  };
}

function mockFetch(
  handler: (input: unknown, init?: RequestInit) => Response | Promise<Response>,
): { calls: FetchCall[]; restore: () => void } {
  const originalFetch = globalThis.fetch;
  const calls: FetchCall[] = [];

  globalThis.fetch = ((input: unknown, init?: RequestInit) => {
    calls.push({ input, init });
    return Promise.resolve(handler(input, init));
  }) as typeof fetch;

  return {
    calls,
    restore: () => {
      globalThis.fetch = originalFetch;
    },
  };
}

function captureConsole(): { logs: string[]; restore: () => void } {
  const originalLog = console.log;
  const originalWarn = console.warn;
  const originalError = console.error;
  const logs: string[] = [];

  const capture = (...args: unknown[]) => {
    logs.push(args.map((value) => String(value)).join(" "));
  };

  console.log = capture;
  console.warn = capture;
  console.error = capture;

  return {
    logs,
    restore: () => {
      console.log = originalLog;
      console.warn = originalWarn;
      console.error = originalError;
    },
  };
}

async function invoke(env: WorkerEnv = validEnv): Promise<void> {
  await worker.scheduled(controller, env, ctx);
}

Deno.test("scheduled handler performs one authenticated POST and validates success", async () => {
  const mock = mockFetch(() => jsonResponse(validBody()));
  const consoleCapture = captureConsole();

  try {
    await invoke();

    assertEquals(mock.calls.length, 1);
    const call = mock.calls[0];
    assertEquals(call.input, FUNCTION_URL);
    assertEquals(call.init?.method, "POST");
    const headers = new Headers(call.init?.headers);
    assertEquals(headers.get("content-type"), "application/json");
    assertEquals(headers.get("x-worker-secret"), TEST_SECRET);
    assertEquals(call.init?.body, JSON.stringify({ limit: 5 }));
    assertEquals(consoleCapture.logs.some((line) => line.includes('"outcome":"completed"')), true);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"claimed":2')), true);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"succeeded":1')), true);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"dead_lettered":1')), true);
    assertFalse(consoleCapture.logs.some((line) => line.includes(TEST_SECRET)));
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler accepts an empty-queue response", async () => {
  const mock = mockFetch(() =>
    jsonResponse(validBody({
      claimed: 0,
      succeeded: 0,
      retryable: 0,
      dead_lettered: 0,
      failed: 0,
      skipped: 0,
      duration_ms: 3,
    }))
  );
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"outcome":"completed"')), true);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"claimed":0')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler does not request when configuration is missing", async () => {
  const cases: WorkerEnv[] = [
    { REPUTATION_WORKER_SECRET: TEST_SECRET },
    { REPUTATION_FUNCTION_URL: FUNCTION_URL },
    { REPUTATION_FUNCTION_URL: "", REPUTATION_WORKER_SECRET: TEST_SECRET },
    { REPUTATION_FUNCTION_URL: FUNCTION_URL, REPUTATION_WORKER_SECRET: "" },
  ];

  for (const env of cases) {
    const mock = mockFetch(() => jsonResponse(validBody()));
    const consoleCapture = captureConsole();

    try {
      await invoke(env);
      assertEquals(mock.calls.length, 0);
      assertEquals(
        consoleCapture.logs.some((line) => line.includes('"outcome":"missing_configuration"')),
        true,
      );
    } finally {
      consoleCapture.restore();
      mock.restore();
    }
  }
});

Deno.test("scheduled handler records HTTP 401 without retrying", async () => {
  const mock = mockFetch(() => new Response("unauthorized", { status: 401 }));
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"status":401')), true);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"outcome":"http_error"')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler records HTTP 500 without retrying", async () => {
  const mock = mockFetch(() => new Response("server error", { status: 500 }));
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"status":500')), true);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"outcome":"http_error"')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler records network failures without retrying", async () => {
  const mock = mockFetch(() => {
    throw new TypeError("network unavailable");
  });
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"outcome":"request_failed"')), true);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"error_class":"network_error"')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler records native timeout errors without retrying", async () => {
  for (const name of ["TimeoutError", "AbortError"]) {
    const mock = mockFetch(() => {
      throw new DOMException("The operation timed out.", name);
    });
    const consoleCapture = captureConsole();

    try {
      await invoke();
      assertEquals(mock.calls.length, 1);
      assertEquals(consoleCapture.logs.some((line) => line.includes('"outcome":"request_failed"')), true);
      assertEquals(consoleCapture.logs.some((line) => line.includes('"error_class":"timeout"')), true);
    } finally {
      consoleCapture.restore();
      mock.restore();
    }
  }
});

Deno.test("scheduled handler rejects malformed JSON", async () => {
  const mock = mockFetch(() => new Response("not-json", { status: 200 }));
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"error_class":"invalid_json"')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler rejects malformed or incomplete response contracts", async () => {
  const bodies: unknown[] = [
    validBody({ ok: false }),
    (() => {
      const body = validBody();
      delete body.claimed;
      return body;
    })(),
    validBody({ succeeded: -1 }),
    validBody({ retryable: 1.5 }),
    validBody({ worker_id: "" }),
  ];

  for (const body of bodies) {
    const mock = mockFetch(() => jsonResponse(body));
    const consoleCapture = captureConsole();

    try {
      await invoke();
      assertEquals(mock.calls.length, 1);
      assertEquals(
        consoleCapture.logs.some((line) => line.includes('"error_class":"contract_validation"')),
        true,
      );
    } finally {
      consoleCapture.restore();
      mock.restore();
    }
  }
});

Deno.test("scheduled handler never logs worker secret or claim token", async () => {
  const mock = mockFetch(() =>
    jsonResponse(validBody({
      claim_token: TEST_CLAIM_TOKEN,
      authorization: "Bearer should-not-log",
    }))
  );
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertFalse(consoleCapture.logs.some((line) => line.includes(TEST_SECRET)));
    assertFalse(consoleCapture.logs.some((line) => line.includes(TEST_CLAIM_TOKEN)));
    assertFalse(consoleCapture.logs.some((line) => line.includes("should-not-log")));
    assertFalse(consoleCapture.logs.some((line) => line.includes("x-worker-secret")));
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("worker has no public fetch handler", () => {
  assertFalse("fetch" in worker);
});
