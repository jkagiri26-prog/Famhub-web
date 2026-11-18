import {
  type MpesaPaymentAttempt,
  type MpesaProvider,
  MpesaProviderNotConfiguredError,
} from "./contract.ts";
import {
  type FinanceGateway,
  initiateMpesaPayment,
  MpesaProviderRejectionError,
  MpesaProviderUnknownOutcomeError,
} from "./orchestrator.ts";

export type ContactUnlockHandlerDeps = {
  provider: MpesaProvider;
  finance: FinanceGateway;
  callbackUrl: string;
};

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

function parseAttempt(
  body: Record<string, unknown>,
): MpesaPaymentAttempt | null {
  const paymentAttemptId = body.paymentAttemptId;
  const obligationId = body.obligationId;
  const phone = body.phone;
  const amount = body.amount;
  const currency = body.currency;
  if (
    typeof paymentAttemptId !== "string" ||
    typeof obligationId !== "string" ||
    typeof phone !== "string" ||
    typeof amount !== "number" ||
    currency !== "KES"
  ) {
    return null;
  }
  return {
    paymentAttemptId,
    phone,
    amount,
    currency,
    accountReference: `contact-unlock:${obligationId}`,
    transactionDesc: "Vunio contact unlock",
  };
}

/**
 * Provider-independent HTTP boundary.
 *
 * Only initiation is exposed here. Provider callbacks are handled by the
 * authenticated Daraja callback boundary, never by this client-facing action.
 * No callback payload is accepted from Flutter.
 */
export async function handleContactUnlockRequest(
  req: Request,
  deps: ContactUnlockHandlerDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return json(405, { ok: false, error: "method_not_allowed" });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch (_) {
    return json(400, { ok: false, error: "invalid_json" });
  }
  if (!isRecord(body) || body.action !== "initiate") {
    return json(400, { ok: false, error: "unsupported_action" });
  }

  const attempt = parseAttempt(body);
  if (!attempt) {
    return json(400, { ok: false, error: "invalid_request" });
  }

  try {
    const result = await initiateMpesaPayment(
      { attempt, callbackUrl: deps.callbackUrl },
      deps,
    );
    return json(202, { ok: true, ...result });
  } catch (error) {
    if (error instanceof MpesaProviderNotConfiguredError) {
      return json(503, { ok: false, error: "mpesa_provider_not_configured" });
    }
    if (error instanceof MpesaProviderRejectionError) {
      return json(502, { ok: false, error: "mpesa_provider_rejected" });
    }
    if (error instanceof MpesaProviderUnknownOutcomeError) {
      return json(503, { ok: false, error: "mpesa_provider_outcome_unknown" });
    }
    return json(400, { ok: false, error: "contact_unlock_initiation_failed" });
  }
}
