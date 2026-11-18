import type { MpesaCallbackEvidence, MpesaProvider } from "./contract.ts";
import {
  type FinanceGateway,
  processMpesaCallback,
  processMpesaFailure,
} from "./orchestrator.ts";
import {
  MpesaCallbackAuthConfigurationError,
  MpesaCallbackAuthenticationError,
  type MpesaCallbackAuthenticator,
  MpesaCallbackPayloadError,
} from "./mpesa_callback_auth.ts";

export type DarajaCallbackDeps = {
  provider: MpesaProvider;
  finance: FinanceGateway;
  authenticate: MpesaCallbackAuthenticator;
};

const JSON_HEADERS = { "Content-Type": "application/json; charset=utf-8" };

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS,
  });
}

/**
 * Provider-specific callback HTTP boundary.
 *
 * The injected authenticator owns request validation and authentication. This
 * handler never confirms a payment directly; it only passes authenticated data
 * to generic M-Pesa orchestration, which delegates all evidence and state
 * changes to Finance.
 */
export async function handleDarajaCallback(
  req: Request,
  deps: DarajaCallbackDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return json(405, { ok: false, error: "method_not_allowed" });
  }

  let parsed;
  try {
    parsed = await deps.authenticate.authenticate(req);
  } catch (error) {
    if (error instanceof MpesaCallbackAuthConfigurationError) {
      return json(503, { ok: false, error: "callback_auth_not_configured" });
    }
    if (error instanceof MpesaCallbackPayloadError) {
      return json(400, { ok: false, error: "invalid_callback_payload" });
    }
    if (error instanceof MpesaCallbackAuthenticationError) {
      return json(401, { ok: false, error: "callback_not_authenticated" });
    }
    return json(401, { ok: false, error: "callback_not_authenticated" });
  }

  let attempt;
  try {
    attempt = await deps.finance.loadAttemptByCheckoutRequestId(
      parsed.checkoutRequestId,
    );
  } catch (_) {
    return json(502, { ok: false, error: "finance_lookup_failed" });
  }
  if (!attempt) {
    return json(404, { ok: false, error: "payment_attempt_not_found" });
  }

  const callback: MpesaCallbackEvidence = {
    authenticated: true,
    checkoutRequestId: parsed.checkoutRequestId,
    resultCode: parsed.resultCode,
    resultDesc: parsed.resultDesc,
    receiptNumber: parsed.receiptNumber,
    amount: parsed.amount,
  };
  const providerEventId =
    `daraja:${parsed.checkoutRequestId}:${parsed.resultCode}:${
      parsed.receiptNumber ?? "none"
    }`;
  const providerVerifiedAt = new Date().toISOString();

  try {
    if (parsed.resultCode === "0") {
      const result = await processMpesaCallback({
        attempt,
        callback,
        providerEventId,
        providerVerifiedAt,
        callbackPayload: parsed.callbackPayload,
      }, deps);
      return json(200, { ok: true, ...result });
    }

    await processMpesaFailure({
      attempt,
      callback,
      providerEventId,
      providerVerifiedAt,
      callbackPayload: parsed.callbackPayload,
    }, deps);
    return json(200, { ok: true, status: "failed" });
  } catch (_) {
    return json(502, { ok: false, error: "callback_processing_failed" });
  }
}
