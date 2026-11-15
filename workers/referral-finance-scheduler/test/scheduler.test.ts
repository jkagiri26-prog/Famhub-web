import { assertEquals, assertFalse } from "https://deno.land/std@0.224.0/assert/mod.ts";
import worker from "../src/index.ts";

const FUNCTION_URL = "https://staging.example.invalid/functions/v1/referral-finance-worker";
const TEST_SECRET = "unit-test-secret-not-real";

type WorkerEnv = {
  SUPABASE_FUNCTION_URL?: string;
  REFERRAL_WORKER_SECRET?: string;
};

type FetchCall = {
  input: unknown;
  init?: RequestInit;
};

const validEnv: WorkerEnv = {
  SUPABASE_FUNCTION_URL: FUNCTION_URL,
  REFERRAL_WORKER_SECRET: TEST_SECRET,
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
    gate_enabled: false,
    selected_count: 1,
    processed_count: 1,
    failed_count: 0,
    ...overrides,
  };
}

function mockFetch(
  handler: (input: unknown, init?: RequestInit) => Promise<Response>,
): { calls: FetchCall[]; restore: () => void } {
  const originalFetch = globalThis.fetch;
  const calls: FetchCall[] = [];

  globalThis.fetch = ((input: unknown, init?: RequestInit) => {
    calls.push({ input, init });
    return handler(input, init);
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
  const mock = mockFetch(async () => jsonResponse(validBody()));
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
    assertEquals(call.init?.body, JSON.stringify({ limit: 20 }));
    assertEquals(consoleCapture.logs.some((line) => line.includes('"outcome":"completed"')), true);
    assertFalse(consoleCapture.logs.some((line) => line.includes(TEST_SECRET)));
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler accepts gate_enabled=false", async () => {
  const mock = mockFetch(async () => jsonResponse(validBody({ gate_enabled: false })));
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"gate_enabled":false')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler records HTTP 401 without retrying", async () => {
  const mock = mockFetch(async () => new Response("unauthorized", { status: 401 }));
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
  const mock = mockFetch(async () => new Response("server error", { status: 500 }));
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
  const mock = mockFetch(async () => {
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

Deno.test("scheduled handler records AbortError as timeout without retrying", async () => {
  const mock = mockFetch(async () => {
    throw new DOMException("aborted", "AbortError");
  });
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"error_class":"timeout"')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler rejects malformed JSON", async () => {
  const mock = mockFetch(async () => new Response("not-json", { status: 200 }));
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

Deno.test("scheduled handler rejects ok=false", async () => {
  const mock = mockFetch(async () => jsonResponse(validBody({ ok: false })));
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"error_class":"contract_validation"')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler rejects missing gate_enabled", async () => {
  const body = validBody();
  delete body.gate_enabled;
  const mock = mockFetch(async () => jsonResponse(body));
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"error_class":"contract_validation"')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler rejects negative counts", async () => {
  const mock = mockFetch(async () => jsonResponse(validBody({ failed_count: -1 })));
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"error_class":"contract_validation"')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler rejects non-integer counts", async () => {
  const mock = mockFetch(async () => jsonResponse(validBody({ selected_count: 1.5 })));
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertEquals(consoleCapture.logs.some((line) => line.includes('"error_class":"contract_validation"')), true);
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("scheduled handler never logs the worker secret", async () => {
  const mock = mockFetch(async () => jsonResponse(validBody()));
  const consoleCapture = captureConsole();

  try {
    await invoke();
    assertEquals(mock.calls.length, 1);
    assertFalse(consoleCapture.logs.some((line) => line.includes(TEST_SECRET)));
    assertFalse(consoleCapture.logs.some((line) => line.includes("x-worker-secret")));
  } finally {
    consoleCapture.restore();
    mock.restore();
  }
});

Deno.test("worker has no public fetch handler", () => {
  assertFalse("fetch" in worker);
});
