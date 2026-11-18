import {
  type MpesaPaymentAttempt,
  type MpesaProvider,
  MpesaProviderNotConfiguredError,
} from "../mpesa-contact-unlock/contract.ts";
import {
  initiateMpesaPayment,
  MpesaProviderRejectionError,
  MpesaProviderUnknownOutcomeError,
} from "../mpesa-contact-unlock/orchestrator.ts";
import type { SubscriptionFinanceGateway } from "./finance_gateway.ts";

export type SubscriptionBillingDeps = {
  provider: MpesaProvider;
  finance: SubscriptionFinanceGateway;
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

/**
 * Authenticated subscription initiation boundary.
 *
 * The client supplies only the cycle, phone and idempotency key. The server
 * obtains the Finance attempt from the cycle, then delegates provider work to
 * the existing generic M-Pesa orchestration. This handler never exposes the
 * service-role confirmation path.
 */
export async function handleSubscriptionBillingRequest(
  req: Request,
  deps: SubscriptionBillingDeps,
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

  const subscriptionCycleId = typeof body.subscriptionCycleId === "string"
    ? body.subscriptionCycleId.trim()
    : "";
  const phone = typeof body.phone === "string" ? body.phone.trim() : "";
  const idempotencyKey = typeof body.idempotencyKey === "string"
    ? body.idempotencyKey.trim()
    : "";
  if (!subscriptionCycleId || !phone || !idempotencyKey) {
    return json(400, { ok: false, error: "invalid_request" });
  }
  if (deps.provider.isConfigured && !deps.provider.isConfigured()) {
    return json(503, { ok: false, error: "mpesa_provider_not_configured" });
  }
  if (!deps.callbackUrl.trim()) {
    return json(500, { ok: false, error: "callback_url_missing" });
  }

  let requested;
  try {
    requested = await deps.finance.requestAnnualSubscriptionMpesaAttempt(
      subscriptionCycleId,
      phone,
      idempotencyKey,
    );
  } catch (_) {
    return json(400, {
      ok: false,
      error: "subscription_payment_request_failed",
    });
  }

  if (requested.status !== "created") {
    if (requested.status === "pending" || requested.status === "processing") {
      return json(202, {
        ok: true,
        paymentAttemptId: requested.paymentAttemptId,
        checkoutRequestId: requested.checkoutRequestId,
        status: requested.status,
      });
    }
    if (requested.status === "succeeded") {
      return json(200, {
        ok: true,
        paymentAttemptId: requested.paymentAttemptId,
        checkoutRequestId: requested.checkoutRequestId,
        status: requested.status,
      });
    }
    return json(409, {
      ok: false,
      error: "subscription_payment_not_retryable",
    });
  }

  const attempt: MpesaPaymentAttempt = {
    paymentAttemptId: requested.paymentAttemptId,
    phone,
    amount: requested.amount,
    currency: requested.currency,
    accountReference: `subscription:${
      requested.subscriptionCycleId || subscriptionCycleId
    }`,
    transactionDesc: "Vunio annual subscription",
  };

  try {
    const result = await initiateMpesaPayment(
      { attempt, callbackUrl: deps.callbackUrl },
      deps,
    );
    return json(202, {
      ok: true,
      paymentAttemptId: result.paymentAttemptId,
      checkoutRequestId: result.checkoutRequestId,
      status: result.status,
    });
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
    return json(400, {
      ok: false,
      error: "subscription_payment_initiation_failed",
    });
  }
}
