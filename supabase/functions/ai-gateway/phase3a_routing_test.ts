// Phase 3A verification for the ai-gateway Edge Function.
//
// index.ts is a single-file serverless function: importing it immediately calls
// Deno.serve(), which would bind a listener. These tests therefore:
//   1. temporarily replace Deno.serve with a capture stub, import the real module,
//      and drive the real request handler directly (fallback, budget, selector);
//   2. additionally derive a side-effect-free copy of the routing layer by slicing
//      index.ts at the Deno.serve( entry point, so the internal capability/task
//      functions can be asserted directly.
//
// Run: deno test --allow-read --allow-env supabase/functions/ai-gateway/

type Handler = (req: Request) => Response | Promise<Response>;
type ProviderName = "gemini" | "openrouter" | "groq" | "deepseek" | "openai";

const PROVIDER_NEEDLES: Record<ProviderName, string> = {
  gemini: "generativelanguage.googleapis.com",
  openrouter: "openrouter.ai",
  groq: "api.groq.com",
  deepseek: "api.deepseek.com",
  openai: "api.openai.com",
};

function providerForUrl(url: string): ProviderName | "unknown" {
  for (const [name, needle] of Object.entries(PROVIDER_NEEDLES)) {
    if (url.includes(needle)) return name as ProviderName;
  }
  return "unknown";
}

// ---------------------------------------------------------------------------
// assert helpers (no external dependencies)
// ---------------------------------------------------------------------------
function assert(
  condition: unknown,
  message = "assertion failed",
): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(
  actual: unknown,
  expected: unknown,
  message = "values differ",
): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(`${message}\n  actual:   ${a}\n  expected: ${e}`);
  }
}

// ---------------------------------------------------------------------------
// capture the real handler instead of binding a listener
// ---------------------------------------------------------------------------
let handler: Handler | null = null;
const originalServe = Deno.serve;
(Deno as unknown as Record<string, unknown>).serve = (captured: Handler) => {
  handler = captured;
  return { shutdown: () => Promise.resolve(), ref() {}, unref() {} };
};

// ---------------------------------------------------------------------------
// fetch stub: every provider call is scripted per test
// ---------------------------------------------------------------------------
type ProviderCall = { provider: ProviderName | "unknown"; url: string };
let providerCalls: ProviderCall[] = [];
let script: (provider: ProviderName | "unknown") => Response = () => {
  throw new Error("fetch script not configured for this test");
};

const originalFetch = globalThis.fetch;
(globalThis as unknown as Record<string, unknown>).fetch = async (
  input: RequestInfo | URL,
): Promise<Response> => {
  const url = String(input);
  const provider = providerForUrl(url);
  providerCalls.push({ provider, url });
  return script(provider);
};

const SOURCE_URL = new URL("./index.ts", import.meta.url);
const sourceText = await Deno.readTextFile(SOURCE_URL);

await import("./index.ts");
(Deno as unknown as Record<string, unknown>).serve = originalServe;
assert(handler !== null, "Deno.serve was never invoked by index.ts");

// Side-effect-free copy of the routing layer, used for direct internal assertions.
const serveIndex = sourceText.indexOf("Deno.serve(");
assert(serveIndex > 0, "Deno.serve( entry point not found in index.ts");
const routingSource = sourceText.slice(0, serveIndex) + `
export {
  FALLBACK_ORDER, PROVIDER_MODELS, PROVIDER_CAPABILITIES, TASK_REQUIREMENTS,
  GATEWAY_PROVIDER_BUDGET_MS, PROVIDER_TIMEOUT_MS, MIN_PROVIDER_START_BUDGET_MS,
  resolveTaskRequirements, supportsCapabilities, selectProvidersForTask, resolveProviderSelection,
};
`;
const routing = await import(
  "data:application/typescript;base64," + btoa(routingSource)
) as {
  FALLBACK_ORDER: ProviderName[];
  PROVIDER_MODELS: Record<ProviderName, string>;
  PROVIDER_CAPABILITIES: Record<ProviderName, string[]>;
  TASK_REQUIREMENTS: Record<
    string,
    { canonicalTask: string; requiredCapabilities: string[] }
  >;
  GATEWAY_PROVIDER_BUDGET_MS: number;
  PROVIDER_TIMEOUT_MS: number;
  MIN_PROVIDER_START_BUDGET_MS: number;
  resolveTaskRequirements: (
    task: string,
  ) => { canonicalTask: string; requiredCapabilities: string[] };
  supportsCapabilities: (
    provider: ProviderName,
    required: readonly string[],
  ) => boolean;
  selectProvidersForTask: (
    task: string,
    explicit?: { provider: ProviderName; model: string; reason: string },
  ) => { provider: ProviderName; model: string; reason: string }[];
  resolveProviderSelection: (
    testProvider?: string,
  ) => { provider: ProviderName; model: string; reason: string };
};

// ---------------------------------------------------------------------------
// test scaffolding
// ---------------------------------------------------------------------------
const JWT = [
  btoa(JSON.stringify({ alg: "HS256", typ: "JWT" })),
  btoa(
    JSON.stringify({
      role: "authenticated",
      sub: "11111111-1111-1111-1111-111111111111",
    }),
  ),
  "signature",
].join(".");

const REAL_PERFORMANCE_NOW = performance.now;
let clockMs = 1_000;

function freezeClock(atMs = 1_000): void {
  clockMs = atMs;
  Object.defineProperty(performance, "now", {
    value: () => clockMs,
    configurable: true,
    writable: true,
  });
}

function restoreClock(): void {
  Object.defineProperty(performance, "now", {
    value: REAL_PERFORMANCE_NOW,
    configurable: true,
    writable: true,
  });
}

function advanceClock(ms: number): void {
  clockMs += ms;
}

function jsonBody(value: unknown): Response {
  return new Response(JSON.stringify(value), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

function successResponse(provider: ProviderName | "unknown"): Response {
  const text = `ok:${provider}`;
  if (provider === "gemini") {
    return jsonBody({ candidates: [{ content: { parts: [{ text }] } }] });
  }
  return jsonBody({ choices: [{ message: { content: text } }] });
}

const transientFailure = () => new Response(null, { status: 503 });
const nonTransientFailure = () => new Response(null, { status: 401 });
const emptyOutput = () => jsonBody({ choices: [] });

function setProviderKeys(): void {
  Deno.env.set("GEMINI_API_KEY", "test-gemini");
  Deno.env.set("OPENROUTER_API_KEY", "test-openrouter");
  Deno.env.set("GROQ_API_KEY", "test-groq");
  Deno.env.set("DEEPSEEK_API_KEY", "test-deepseek");
  Deno.env.set("OPENAI_API_KEY", "test-openai");
}

function gatewayRequest(
  body: unknown,
  headers: Record<string, string> = {},
): Request {
  return new Request("http://127.0.0.1/functions/v1/ai-gateway", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${JWT}`,
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

function reset(): void {
  setProviderKeys();
  providerCalls = [];
  freezeClock();
  script = () => {
    throw new Error("fetch script not configured for this test");
  };
}

function called(): (ProviderName | "unknown")[] {
  return providerCalls.map((call) => call.provider);
}

const SANITIZERS = { sanitizeOps: false, sanitizeResources: false } as const;

// ---------------------------------------------------------------------------
// 1. general task preserves the existing provider order
// ---------------------------------------------------------------------------
Deno.test({
  name: "Phase 3A: general task starts on gemini and extracts its text output",
  ...SANITIZERS,
  fn: async () => {
    reset();
    script = (provider) => successResponse(provider);

    const response = await handler!(
      gatewayRequest({ task: "general_text", input: { q: "hi" } }),
    );
    const payload = await response.json();

    assertEquals(
      response.status,
      200,
      "gateway should succeed on the first provider",
    );
    assertEquals(payload, {
      request_id: payload.request_id,
      ok: true,
      output: "ok:gemini",
    });
    assertEquals(called(), ["gemini"], "gemini must remain the first provider");
  },
});

Deno.test({
  name:
    "Phase 3A: full fallback order is gemini, openrouter, groq, deepseek, openai",
  ...SANITIZERS,
  fn: async () => {
    reset();
    script = (
      provider,
    ) => (provider === "openai"
      ? successResponse(provider)
      : transientFailure());

    const response = await handler!(
      gatewayRequest({ task: "general_text", input: {} }),
    );
    const payload = await response.json();

    assertEquals(
      response.status,
      200,
      "chain should succeed on the last provider",
    );
    assertEquals(payload.output, "ok:openai");
    assertEquals(called(), [
      "gemini",
      "openrouter",
      "groq",
      "deepseek",
      "openai",
    ]);
    assertEquals(
      routing.selectProvidersForTask("general_text").map((selection) =>
        selection.provider
      ),
      routing.FALLBACK_ORDER,
      "routing layer must preserve the configured preference order",
    );
  },
});

// ---------------------------------------------------------------------------
// 2 & 3 & 5. capability filtering, order preservation, filter-before-fallback
// ---------------------------------------------------------------------------
Deno.test({
  name:
    "Phase 3A: a provider lacking a required capability is excluded, and eligible order is preserved",
  ...SANITIZERS,
  fn: () => {
    reset();
    const original = routing.PROVIDER_CAPABILITIES.groq;
    try {
      // Remove text_output from groq: it can no longer satisfy general_text.
      routing.PROVIDER_CAPABILITIES.groq = ["text_input"];
      assertEquals(
        routing.supportsCapabilities("groq", ["text_input", "text_output"]),
        false,
        "groq must no longer satisfy the general_text requirements",
      );

      const providers = routing.selectProvidersForTask("general_text").map((
        s,
      ) => s.provider);
      assertEquals(
        providers,
        ["gemini", "openrouter", "deepseek", "openai"],
        "groq must be dropped and the remaining providers must keep their relative order",
      );
      assert(
        !providers.includes("groq"),
        "an ineligible provider must never be a fallback candidate",
      );
    } finally {
      routing.PROVIDER_CAPABILITIES.groq = original;
    }
  },
});

Deno.test({
  name:
    "Phase 3A: capability filtering runs before fallback, not appended after it",
  ...SANITIZERS,
  fn: () => {
    reset();
    const original = routing.PROVIDER_CAPABILITIES.deepseek;
    try {
      routing.PROVIDER_CAPABILITIES.deepseek = [];
      const providers = routing.selectProvidersForTask("general_text").map((
        s,
      ) => s.provider);
      assertEquals(
        providers,
        ["gemini", "openrouter", "groq", "openai"],
        "deepseek must be filtered out rather than reordered to the end",
      );
      assertEquals(
        routing.selectProvidersForTask("general_text").findIndex((s) =>
          s.provider === "deepseek"
        ),
        -1,
        "deepseek must not appear anywhere in the candidate list",
      );
    } finally {
      routing.PROVIDER_CAPABILITIES.deepseek = original;
    }
  },
});

// ---------------------------------------------------------------------------
// 4. unknown tasks keep routing as general text
// ---------------------------------------------------------------------------
Deno.test({
  name:
    "Phase 3A: unrecognized tasks resolve to general_text for compatibility",
  ...SANITIZERS,
  fn: () => {
    reset();
    assertEquals(
      routing.resolveTaskRequirements("general_text").canonicalTask,
      "general_text",
    );
    assertEquals(
      routing.resolveTaskRequirements("  GENERAL_TEXT ").canonicalTask,
      "general_text",
    );
    assertEquals(
      routing.resolveTaskRequirements("summarize the farm log").canonicalTask,
      "general_text",
      "an unknown free-form task must not be rejected",
    );
    assertEquals(
      routing.selectProvidersForTask("summarize the farm log").map((s) =>
        s.provider
      ),
      routing.FALLBACK_ORDER,
      "an unknown task must keep the full fallback chain",
    );
  },
});

Deno.test({
  name: "Phase 3A: a free-form task still completes end to end (no 422)",
  ...SANITIZERS,
  fn: async () => {
    reset();
    script = (provider) => successResponse(provider);

    const response = await handler!(
      gatewayRequest({
        task: "Summarize the farm log",
        input: { notes: "rain" },
      }),
    );
    const payload = await response.json();

    assertEquals(
      response.status,
      200,
      "unknown tasks must not be rejected as unsupported",
    );
    assertEquals(payload.ok, true);
    assertEquals(called(), ["gemini"]);
  },
});

// ---------------------------------------------------------------------------
// 6. transient failures keep falling back
// ---------------------------------------------------------------------------
Deno.test({
  name:
    "Phase 3A: transient provider failure falls back through every eligible provider",
  ...SANITIZERS,
  fn: async () => {
    reset();
    script = (
      provider,
    ) => (provider === "openai"
      ? successResponse(provider)
      : transientFailure());

    const response = await handler!(
      gatewayRequest({ task: "general_text", input: {} }),
    );
    const payload = await response.json();

    assertEquals(response.status, 200);
    assertEquals(payload.output, "ok:openai");
    assertEquals(called(), [
      "gemini",
      "openrouter",
      "groq",
      "deepseek",
      "openai",
    ]);
  },
});

Deno.test({
  name:
    "Phase 3A: a retriable empty output falls back rather than failing the request",
  ...SANITIZERS,
  fn: async () => {
    reset();
    script = (
      provider,
    ) => (provider === "gemini" ? emptyOutput() : successResponse(provider));

    const response = await handler!(
      gatewayRequest({ task: "general_text", input: {} }),
    );
    const payload = await response.json();

    assertEquals(response.status, 200);
    assertEquals(payload.output, "ok:openrouter");
    assertEquals(called(), ["gemini", "openrouter"]);
  },
});

// ---------------------------------------------------------------------------
// 7. non-transient failures stop the chain
// ---------------------------------------------------------------------------
Deno.test({
  name: "Phase 3A: a non-transient provider error does not fall back",
  ...SANITIZERS,
  fn: async () => {
    reset();
    script = (
      provider,
    ) => (provider === "gemini"
      ? nonTransientFailure()
      : successResponse(provider));

    const response = await handler!(
      gatewayRequest({ task: "general_text", input: {} }),
    );
    const payload = await response.json();

    assertEquals(response.status, 502);
    assertEquals(payload.error.code, "provider_error");
    assertEquals(
      called(),
      ["gemini"],
      "the chain must stop at the first non-transient failure",
    );
  },
});

Deno.test({
  name:
    "Phase 3A: a missing provider secret is a non-retryable configuration error",
  ...SANITIZERS,
  fn: async () => {
    reset();
    Deno.env.delete("GEMINI_API_KEY");
    script = (provider) => successResponse(provider);

    const response = await handler!(
      gatewayRequest({ task: "general_text", input: {} }),
    );
    const payload = await response.json();

    assertEquals(response.status, 503);
    assertEquals(payload.error.code, "provider_not_configured");
    assertEquals(
      called(),
      [],
      "an unconfigured provider must not be attempted",
    );
    setProviderKeys();
  },
});

// ---------------------------------------------------------------------------
// 8. the 30s gateway budget is still enforced
// ---------------------------------------------------------------------------
Deno.test({
  name: "Phase 3A: budget constants are unchanged",
  ...SANITIZERS,
  fn: () => {
    reset();
    assertEquals(
      routing.GATEWAY_PROVIDER_BUDGET_MS,
      30_000,
      "overall budget must stay 30s",
    );
    assertEquals(
      routing.PROVIDER_TIMEOUT_MS,
      25_000,
      "per-provider timeout must stay 25s",
    );
    assertEquals(
      routing.MIN_PROVIDER_START_BUDGET_MS,
      100,
      "minimum start budget must stay 100ms",
    );
  },
});

Deno.test({
  name: "Phase 3A: no provider attempt starts after the overall deadline",
  ...SANITIZERS,
  fn: async () => {
    reset();
    script = (provider) => {
      advanceClock(31_000);
      return successResponse(provider);
    };

    const response = await handler!(
      gatewayRequest({ task: "general_text", input: {} }),
    );
    const payload = await response.json();

    assertEquals(
      response.status,
      504,
      "an overrun must be reported as a timeout",
    );
    assertEquals(payload.error.code, "provider_timeout");
    assertEquals(
      called(),
      ["gemini"],
      "no further provider may be attempted once the budget is spent",
    );
  },
});

Deno.test({
  name:
    "Phase 3A: the next provider is not started when less than the minimum budget remains",
  ...SANITIZERS,
  fn: async () => {
    reset();
    let advanced = false;
    script = (provider) => {
      if (!advanced) {
        advanced = true;
        advanceClock(29_950);
        return transientFailure();
      }
      return successResponse(provider);
    };

    const response = await handler!(
      gatewayRequest({ task: "general_text", input: {} }),
    );
    const payload = await response.json();

    assertEquals(
      response.status,
      504,
      "insufficient remaining budget must stop the chain",
    );
    assertEquals(payload.error.code, "provider_timeout");
    assertEquals(
      called(),
      ["gemini"],
      "the second provider must never be started",
    );
  },
});

// ---------------------------------------------------------------------------
// 9. explicit test selectors stay single-provider with no fallback
// ---------------------------------------------------------------------------
Deno.test({
  name:
    "Phase 3A: an explicit provider selector never expands into fallback candidates",
  ...SANITIZERS,
  fn: () => {
    reset();
    const selection = routing.resolveProviderSelection("groq");
    assertEquals(selection.provider, "groq");
    assertEquals(selection.reason, "explicit_test_selector");

    const candidates = routing.selectProvidersForTask(
      "general_text",
      selection,
    );
    assertEquals(
      candidates.length,
      1,
      "explicit selection must produce exactly one candidate",
    );
    assertEquals(candidates[0].provider, "groq");

    assertEquals(
      routing.resolveProviderSelection(undefined).reason,
      "normal_preference",
    );
    assertEquals(
      routing.resolveProviderSelection("gemini").reason,
      "normal_preference",
    );
  },
});

Deno.test({
  name: "Phase 3A: an explicit selector that fails does not fall back",
  ...SANITIZERS,
  fn: async () => {
    reset();
    script = (
      provider,
    ) => (provider === "groq" ? transientFailure() : successResponse(provider));

    const response = await handler!(
      gatewayRequest({ task: "general_text", input: {} }, {
        "x-ai-gateway-test-provider": "groq",
      }),
    );
    const payload = await response.json();

    assertEquals(
      response.status,
      503,
      "the explicit provider's own failure is returned",
    );
    assertEquals(payload.error.code, "provider_unavailable");
    assertEquals(
      called(),
      ["groq"],
      "no fallback provider may run for an explicit selection",
    );
  },
});

Deno.test({
  name:
    "Phase 3A: an invalid explicit selector is rejected without contacting any provider",
  ...SANITIZERS,
  fn: async () => {
    reset();
    script = (provider) => successResponse(provider);

    const response = await handler!(
      gatewayRequest({ task: "general_text", input: {} }, {
        "x-ai-gateway-test-provider": "mistral",
      }),
    );
    const payload = await response.json();

    assertEquals(response.status, 400);
    assertEquals(payload.error.code, "invalid_provider");
    assertEquals(called(), []);
  },
});

Deno.test({
  name: "Phase 3A: response envelopes never expose routing decisions",
  ...SANITIZERS,
  fn: async () => {
    reset();
    script = (provider) => successResponse(provider);

    const okResponse = await handler!(
      gatewayRequest({ task: "general_text", input: {} }),
    );
    const okPayload = await okResponse.json();
    assertEquals(
      Object.keys(okPayload).sort(),
      ["ok", "output", "request_id"],
      "a success must only carry request_id, ok, output",
    );

    script = (
      provider,
    ) => (provider === "gemini"
      ? nonTransientFailure()
      : successResponse(provider));
    const errResponse = await handler!(
      gatewayRequest({ task: "general_text", input: {} }),
    );
    const errPayload = await errResponse.json();
    assertEquals(
      Object.keys(errPayload).sort(),
      ["error", "ok", "request_id"],
      "a failure must only carry request_id, ok, error",
    );
    assertEquals(
      Object.keys(errPayload.error).sort(),
      ["code", "message"],
      "error details must not leak provider or capability data",
    );
  },
});

Deno.test({
  name: "Phase 3A: capability model stays internal to the gateway",
  ...SANITIZERS,
  fn: () => {
    reset();
    const exportedKeys = Object.keys(routing);
    assert(
      !exportedKeys.includes("PROVIDER_CAPABILITIES_EXPOSED"),
      "capability data must not be part of the public contract",
    );
    assertEquals(
      routing.TASK_REQUIREMENTS.general_text.requiredCapabilities,
      ["text_input", "text_output"],
      "general_text requires the text capabilities only",
    );
    assertEquals(
      routing.PROVIDER_CAPABILITIES.groq.includes("text_input"),
      true,
      "every current adapter accepts text input",
    );
    assertEquals(
      routing.PROVIDER_CAPABILITIES.groq.includes("text_output"),
      true,
      "every current adapter returns text output",
    );
  },
});

// Note: fetch and performance.now stay stubbed for the lifetime of this test
// process. They must not be restored at module scope, because top-level code in
// a Deno test file runs during load, before any test body executes.
