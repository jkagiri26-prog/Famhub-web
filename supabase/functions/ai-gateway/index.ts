const MAX_BODY_BYTES = 1_048_576;
const MAX_PROMPT_BYTES = 100_000;
const MAX_OUTPUT_TOKENS = 1_024;
const PROVIDER_TIMEOUT_MS = 25_000;
const GATEWAY_PROVIDER_BUDGET_MS = 30_000;
const MIN_PROVIDER_START_BUDGET_MS = 100;
const JSON_HEADERS = { "Content-Type": "application/json; charset=utf-8" };

type Provider = "gemini" | "openrouter" | "groq" | "deepseek" | "openai";
type Capability = "text_input" | "text_output";
type CanonicalTask = "general_text";
type TaskRequirements = {
  canonicalTask: CanonicalTask;
  requiredCapabilities: readonly Capability[];
};
type ProviderSelection = {
  provider: Provider;
  model: string;
  reason: "normal_preference" | "explicit_test_selector" | "fallback";
};
type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue };
type GatewayRequest = {
  task: string;
  input: JsonValue;
  context?: { [key: string]: JsonValue };
};
type ProviderFailure = {
  ok: false;
  status: number;
  code: string;
  message: string;
  retryable: boolean;
};
type ProviderSuccess = { ok: true; output: string };
type ProviderResult = ProviderSuccess | ProviderFailure;

const FALLBACK_ORDER: Provider[] = ["gemini", "openrouter", "groq", "deepseek", "openai"];
const PROVIDER_MODELS: Record<Provider, string> = {
  gemini: "gemini-2.5-flash",
  openrouter: "openai/gpt-4.1-mini",
  groq: "llama-3.3-70b-versatile",
  deepseek: "deepseek-chat",
  openai: "gpt-4.1-mini",
};
const PROVIDER_URLS: Record<Provider, string> = {
  gemini: `https://generativelanguage.googleapis.com/v1beta/models/${PROVIDER_MODELS.gemini}:generateContent`,
  openrouter: "https://openrouter.ai/api/v1/chat/completions",
  groq: "https://api.groq.com/openai/v1/chat/completions",
  deepseek: "https://api.deepseek.com/chat/completions",
  openai: "https://api.openai.com/v1/chat/completions",
};
const PROVIDER_KEY_NAMES: Record<Provider, string> = {
  gemini: "GEMINI_API_KEY",
  openrouter: "OPENROUTER_API_KEY",
  groq: "GROQ_API_KEY",
  deepseek: "DEEPSEEK_API_KEY",
  openai: "OPENAI_API_KEY",
};

// The current adapters all send text prompts and extract text completions.
// They do not currently integrate structured-output or image-input modes.
const PROVIDER_CAPABILITIES: Record<Provider, readonly Capability[]> = {
  gemini: ["text_input", "text_output"],
  openrouter: ["text_input", "text_output"],
  groq: ["text_input", "text_output"],
  deepseek: ["text_input", "text_output"],
  openai: ["text_input", "text_output"],
};

const TASK_REQUIREMENTS: Record<CanonicalTask, TaskRequirements> = {
  general_text: {
    canonicalTask: "general_text",
    requiredCapabilities: ["text_input", "text_output"],
  },
};

function resolveTaskRequirements(task: string): TaskRequirements {
  const canonicalKey = task.trim().toLowerCase();
  if (canonicalKey === "general_text") return TASK_REQUIREMENTS.general_text;
  // The existing task field is free-form prompt text, not a closed task enum.
  // Preserve compatibility by routing every unrecognized value as general text.
  return TASK_REQUIREMENTS.general_text;
}

function supportsCapabilities(provider: Provider, required: readonly Capability[]): boolean {
  const available = PROVIDER_CAPABILITIES[provider];
  return required.every((capability) => available.includes(capability));
}

function selectProvidersForTask( task: string, explicitSelection?: ProviderSelection, ): ProviderSelection[] {
  const requirements = resolveTaskRequirements(task);
  const eligibleProviders = FALLBACK_ORDER.filter((provider) =>
    supportsCapabilities(provider, requirements.requiredCapabilities)
  );

  // Explicit provider selectors remain isolated: they are never expanded into fallback candidates.
  if (explicitSelection) {
    return eligibleProviders.includes(explicitSelection.provider) ? [explicitSelection] : [];
  }

  return eligibleProviders.map((provider, index) => ({
    provider,
    model: PROVIDER_MODELS[provider],
    reason: index === 0 ? "normal_preference" : "fallback",
  }));
}

function resolveProviderSelection(testProvider: string | undefined): ProviderSelection {
  if (testProvider === "groq" || testProvider === "openai" || testProvider === "deepseek" || testProvider === "openrouter") {
    return {
      provider: testProvider,
      model: PROVIDER_MODELS[testProvider],
      reason: "explicit_test_selector",
    };
  }
  const provider = FALLBACK_ORDER[0];
  return { provider, model: PROVIDER_MODELS[provider], reason: "normal_preference" };
}

function jsonResponse(status: number, requestId: string, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify({ request_id: requestId, ...body }), {
    status,
    headers: JSON_HEADERS,
  });
}

function gatewayBudgetExceededResponse(requestId: string): Response {
  return jsonResponse(504, requestId, {
    ok: false,
    error: { code: "provider_timeout", message: "The AI provider did not respond in time." },
  });
}

function decodeVerifiedClaims(token: string): Record<string, unknown> | null {
  // The Supabase Edge gateway validates the signature while verify_jwt is enabled.
  // This only reads claims from that already-verified token.
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload + "=".repeat((4 - (payload.length % 4)) % 4);
    const value: unknown = JSON.parse(atob(padded));
    if (typeof value !== "object" || value === null || Array.isArray(value)) return null;
    return value as Record<string, unknown>;
  } catch {
    return null;
  }
}

function isJsonObject(value: unknown): value is Record<string, JsonValue> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function failure(status: number, code: string, message: string, retryable: boolean): ProviderFailure {
  return { ok: false, status, code, message, retryable };
}

function extractOutput(provider: Provider, data: unknown): string {
  if (provider === "gemini") {
    const candidates = isRecord(data) ? data.candidates : undefined;
    const firstCandidate = Array.isArray(candidates) ? candidates[0] : undefined;
    const content = isRecord(firstCandidate) ? firstCandidate.content : undefined;
    const parts = isRecord(content) ? content.parts : undefined;
    return Array.isArray(parts)
      ? parts
          .filter((part) => isRecord(part) && typeof part.text === "string")
          .map((part) => (part as Record<string, unknown>).text as string)
          .join("")
      : "";
  }

  const choices = isRecord(data) ? data.choices : undefined;
  const firstChoice = Array.isArray(choices) ? choices[0] : undefined;
  const message = isRecord(firstChoice) ? firstChoice.message : undefined;
  return isRecord(message) && typeof message.content === "string" ? message.content : "";
}

async function executeProvider( selection: ProviderSelection, prompt: string, attemptTimeoutMs: number, ): Promise<ProviderResult> {
  const apiKey = Deno.env.get(PROVIDER_KEY_NAMES[selection.provider]);
  if (!apiKey) {
    // A missing server-side secret is configuration failure, not a transient provider outage.
    return failure(503, "provider_not_configured", "The AI provider is not configured.", false);
  }

  const headers: Record<string, string> = { "Content-Type": "application/json" };
  let requestBody: Record<string, unknown>;
  if (selection.provider === "gemini") {
    headers["x-goog-api-key"] = apiKey;
    requestBody = {
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: MAX_OUTPUT_TOKENS },
    };
  } else {
    headers.Authorization = `Bearer ${apiKey}`;
    requestBody = {
      model: selection.model,
      messages: [{ role: "user", content: prompt }],
      ...(selection.provider === "openai"
        ? { max_completion_tokens: MAX_OUTPUT_TOKENS }
        : { max_tokens: MAX_OUTPUT_TOKENS }),
      stream: false,
    };
  }

  const controller = new AbortController();
  let timedOut = false;
  const timeout = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, attemptTimeoutMs);

  try {
    const response = await fetch(PROVIDER_URLS[selection.provider], {
      method: "POST",
      headers,
      body: JSON.stringify(requestBody),
      signal: controller.signal,
    });

    if (!response.ok) {
      // Only rate limiting and upstream/transient statuses qualify for fallback.
      // Other 4xx statuses (including provider auth or malformed-request errors) stop the chain.
      if (response.status === 408 || response.status === 425 || response.status === 429 || response.status >= 500) {
        return failure(503, "provider_unavailable", "The AI provider is temporarily unavailable.", true);
      }
      return failure(502, "provider_error", "The AI provider request failed.", false);
    }

    let data: unknown;
    try {
      data = await response.json();
    } catch {
      // A successful HTTP status with an unreadable upstream response is treated as transient.
      return failure(502, "provider_invalid_response", "The AI provider returned an invalid response.", true);
    }

    const output = extractOutput(selection.provider, data);
    if (!output) {
      return failure(502, "provider_empty_response", "The AI provider returned no text output.", true);
    }
    return { ok: true, output };
  } catch {
    if (timedOut) {
      return failure(504, "provider_timeout", "The AI provider did not respond in time.", true);
    }
    return failure(502, "provider_unavailable", "The AI provider could not be reached.", true);
  } finally {
    clearTimeout(timeout);
  }
}

Deno.serve(async (req: Request) => {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: {
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "authorization, content-type, apikey",
      "Access-Control-Max-Age": "86400",
    } });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, requestId, {
      ok: false,
      error: { code: "method_not_allowed", message: "Use POST for gateway requests." },
    });
  }

  const authorization = req.headers.get("Authorization");
  const bearer = authorization?.match(/^Bearer\s+(\S+)$/i);
  if (!bearer) {
    return jsonResponse(401, requestId, {
      ok: false,
      error: { code: "unauthorized", message: "A signed-in user is required." },
    });
  }

  const claims = decodeVerifiedClaims(bearer[1]);
  if (!claims || claims.role !== "authenticated" || typeof claims.sub !== "string" || claims.sub.length === 0) {
    return jsonResponse(401, requestId, {
      ok: false,
      error: { code: "unauthorized", message: "A signed-in user is required." },
    });
  }

  const declaredLength = Number(req.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    return jsonResponse(413, requestId, {
      ok: false,
      error: { code: "payload_too_large", message: "Request body exceeds the 1 MiB limit." },
    });
  }

  if (!(req.headers.get("Content-Type") ?? "").toLowerCase().includes("application/json")) {
    return jsonResponse(415, requestId, {
      ok: false,
      error: { code: "unsupported_media_type", message: "Content-Type must be application/json." },
    });
  }

  let rawBody: string;
  try {
    rawBody = await req.text();
  } catch {
    return jsonResponse(400, requestId, {
      ok: false,
      error: { code: "invalid_request", message: "Request body could not be read." },
    });
  }

  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
    return jsonResponse(413, requestId, {
      ok: false,
      error: { code: "payload_too_large", message: "Request body exceeds the 1 MiB limit." },
    });
  }

  let body: unknown;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return jsonResponse(400, requestId, {
      ok: false,
      error: { code: "invalid_json", message: "Request body must be valid JSON." },
    });
  }

  if (!isJsonObject(body)) {
    return jsonResponse(400, requestId, {
      ok: false,
      error: { code: "invalid_request", message: "Request body must be a JSON object." },
    });
  }

  if (typeof body.task !== "string" || body.task.trim().length === 0 || body.task.trim().length > 128) {
    return jsonResponse(400, requestId, {
      ok: false,
      error: { code: "invalid_task", message: "task must be a non-empty string of at most 128 characters." },
    });
  }

  if (!("input" in body) || body.input === null) {
    return jsonResponse(400, requestId, {
      ok: false,
      error: { code: "invalid_input", message: "input is required and cannot be null." },
    });
  }

  if ("context" in body && !isJsonObject(body.context)) {
    return jsonResponse(400, requestId, {
      ok: false,
      error: { code: "invalid_context", message: "context, when provided, must be a JSON object." },
    });
  }

  const gatewayRequest: GatewayRequest = {
    task: body.task.trim(),
    input: body.input as JsonValue,
    ...(body.context === undefined ? {} : { context: body.context as { [key: string]: JsonValue } }),
  };
  const prompt = [
    "Complete the requested task using the supplied JSON input and optional context.",
    `Task: ${gatewayRequest.task}`,
    `Input (JSON): ${JSON.stringify(gatewayRequest.input)}`,
    ...(gatewayRequest.context === undefined
      ? []
      : [`Context (JSON): ${JSON.stringify(gatewayRequest.context)}`]),
  ].join("\n\n");

  if (new TextEncoder().encode(prompt).byteLength > MAX_PROMPT_BYTES) {
    return jsonResponse(413, requestId, {
      ok: false,
      error: { code: "input_too_large", message: "Combined task, input, and context exceed the 100 kB limit." },
    });
  }

  const testProviderHeader = req.headers.get("x-ai-gateway-test-provider");
  const normalizedTestProvider = testProviderHeader?.trim().toLowerCase();
  if (testProviderHeader && normalizedTestProvider !== "groq" && normalizedTestProvider !== "openai" && normalizedTestProvider !== "deepseek" && normalizedTestProvider !== "openrouter") {
    return jsonResponse(400, requestId, {
      ok: false,
      error: { code: "invalid_provider", message: "The test provider header accepts 'groq', 'openai', 'deepseek', or 'openrouter'." },
    });
  }

  const resolvedSelection = resolveProviderSelection(normalizedTestProvider);
  const isExplicitSelection = resolvedSelection.reason === "explicit_test_selector";
  const selections = selectProvidersForTask(
    gatewayRequest.task,
    isExplicitSelection ? resolvedSelection : undefined,
  );

  if (selections.length === 0) {
    return jsonResponse(422, requestId, {
      ok: false,
      error: { code: "unsupported_task", message: "No configured provider supports the requested task." },
    });
  }

  // Start the existing monotonic budget immediately before provider execution.
  const providerExecutionStartedAt = performance.now();
  const providerDeadline = providerExecutionStartedAt + GATEWAY_PROVIDER_BUDGET_MS;

  let lastFailure: ProviderFailure | null = null;
  for (let index = 0; index < selections.length; index++) {
    const remainingMs = providerDeadline - performance.now();
    if (remainingMs < MIN_PROVIDER_START_BUDGET_MS) {
      return gatewayBudgetExceededResponse(requestId);
    }

    const attemptTimeoutMs = Math.min(PROVIDER_TIMEOUT_MS, Math.floor(remainingMs));
    const result = await executeProvider(selections[index], prompt, attemptTimeoutMs);

    if (performance.now() >= providerDeadline) {
      return gatewayBudgetExceededResponse(requestId);
    }

    if (result.ok) {
      return jsonResponse(200, requestId, { ok: true, output: result.output });
    }

    lastFailure = result;
    const hasNextProvider = index < selections.length - 1;
    if (!result.retryable || !hasNextProvider) {
      return jsonResponse(result.status, requestId, {
        ok: false,
        error: { code: result.code, message: result.message },
      });
    }
  }

  const finalFailure = lastFailure ?? failure(503, "provider_unavailable", "The AI provider is temporarily unavailable.", false);
  return jsonResponse(finalFailure.status, requestId, {
    ok: false,
    error: { code: finalFailure.code, message: finalFailure.message },
  });
}); 