import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { MpesaPaymentAttempt } from "../mpesa-contact-unlock/contract.ts";
import { UnconfiguredMpesaProvider } from "../mpesa-contact-unlock/contract.ts";
import {
  type FinanceGateway,
  MpesaProviderRejectionError,
  MpesaProviderUnknownOutcomeError,
  processMpesaCallback,
} from "../mpesa-contact-unlock/orchestrator.ts";
import { MockMpesaProvider } from "../mpesa-contact-unlock/mock_provider.ts";
import { handleDarajaCallback } from "../mpesa-contact-unlock/daraja_callback.ts";
import { createDarajaCallbackAuthenticator } from "../mpesa-contact-unlock/daraja_callback_auth.ts";
import type {
  MpesaAuthenticatedCallback,
  MpesaCallbackAuthenticator,
} from "../mpesa-contact-unlock/mpesa_callback_auth.ts";
import { handleSubscriptionBillingRequest } from "./handler.ts";
import type {
  SubscriptionAttemptRequest,
  SubscriptionFinanceGateway,
} from "./finance_gateway.ts";

const attempt: MpesaPaymentAttempt = {
  paymentAttemptId: "attempt-1",
  checkoutRequestId: "checkout-1",
  phone: "254712345678",
  amount: 12000,
  currency: "KES",
};

class FakeGateway implements SubscriptionFinanceGateway {
  requestStatus = "created";
  requestCheckout: string | null = null;
  requestCalls = 0;
  claimCalls = 0;
  completionCalls: Array<{
    id: string;
    checkout: string | null;
    code?: string | null;
    message?: string | null;
  }> = [];
  evidenceCalls = 0;
  confirmCalls: Array<{ attempt: string; event: string }> = [];
  failureCalls = 0;
  loadedAttempt: MpesaPaymentAttempt | null = attempt;

  async requestAnnualSubscriptionMpesaAttempt(
    subscriptionCycleId: string,
    _phone: string,
    _idempotencyKey: string,
  ): Promise<SubscriptionAttemptRequest> {
    this.requestCalls++;
    return {
      paymentAttemptId: "attempt-1",
      subscriptionCycleId,
      obligationId: "obligation-1",
      amount: 12000,
      currency: "KES",
      status: this.requestStatus,
      checkoutRequestId: this.requestCheckout,
    };
  }

  async getAttemptState(): Promise<SubscriptionAttemptRequest> {
    return {
      paymentAttemptId: "attempt-1",
      subscriptionCycleId: "cycle-1",
      obligationId: "obligation-1",
      amount: 12000,
      currency: "KES",
      status: this.requestStatus,
      checkoutRequestId: this.requestCheckout,
    };
  }

  async claimAttempt() {
    this.claimCalls++;
    return { status: "processing" as const };
  }

  async completeInitiation(
    id: string,
    checkout: string | null,
    code: string | null = null,
    message: string | null = null,
  ) {
    this.completionCalls.push({ id, checkout, code, message });
  }

  async recordVerificationEvidence() {
    this.evidenceCalls++;
    return "event-1";
  }

  async confirmPayment(attemptId: string, event: string) {
    this.confirmCalls.push({ attempt: attemptId, event });
    return "payment-1";
  }

  async loadAttemptByCheckoutRequestId() {
    return this.loadedAttempt;
  }

  async recordDefinitiveFailure() {
    this.failureCalls++;
    return "failure-event-1";
  }
}

function request(body: unknown, method = "POST"): Request {
  return new Request("http://localhost/subscription-billing", {
    method,
    headers: { "content-type": "application/json" },
    body: method === "POST" ? JSON.stringify(body) : undefined,
  });
}

const initiateBody = {
  action: "initiate",
  subscriptionCycleId: "cycle-1",
  phone: "254712345678",
  idempotencyKey: "subscription-attempt-1",
};

Deno.test("subscription initiation claims, initiates, and records pending state", async () => {
  const finance = new FakeGateway();
  const provider = new MockMpesaProvider();
  const response = await handleSubscriptionBillingRequest(
    request(initiateBody),
    {
      provider,
      finance,
      callbackUrl: "https://example.test/subscription/callback",
    },
  );

  assertEquals(response.status, 202);
  assertEquals(finance.requestCalls, 1);
  assertEquals(finance.claimCalls, 1);
  assertEquals(finance.completionCalls.length, 1);
  assertEquals(provider.initiationCalls.length, 1);
  assertEquals(
    provider.initiationCalls[0].accountReference,
    "subscription:cycle-1",
  );
});

Deno.test("subscription initiation is unavailable when provider is unconfigured", async () => {
  const finance = new FakeGateway();
  const response = await handleSubscriptionBillingRequest(
    request(initiateBody),
    {
      provider: new UnconfiguredMpesaProvider(),
      finance,
      callbackUrl: "https://example.test/subscription/callback",
    },
  );

  assertEquals(response.status, 503);
  assertEquals(finance.requestCalls, 0);
  assertEquals(finance.claimCalls, 0);
});

Deno.test("definitive provider rejection fails the Finance attempt", async () => {
  const finance = new FakeGateway();
  const provider = new MockMpesaProvider();
  provider.initiationError = new MpesaProviderRejectionError(
    "1032",
    "Cancelled",
  );
  const response = await handleSubscriptionBillingRequest(
    request(initiateBody),
    {
      provider,
      finance,
      callbackUrl: "https://example.test/subscription/callback",
    },
  );

  assertEquals(response.status, 502);
  assertEquals(finance.completionCalls.length, 1);
  assertEquals(finance.completionCalls[0].code, "1032");
});

Deno.test("unknown provider outcome remains reconcilable", async () => {
  const finance = new FakeGateway();
  const provider = new MockMpesaProvider();
  provider.initiationError = new MpesaProviderUnknownOutcomeError();
  const response = await handleSubscriptionBillingRequest(
    request(initiateBody),
    {
      provider,
      finance,
      callbackUrl: "https://example.test/subscription/callback",
    },
  );

  assertEquals(response.status, 503);
  assertEquals(finance.claimCalls, 1);
  assertEquals(finance.completionCalls.length, 0);
});

Deno.test("duplicate initiation reuses a pending attempt without provider replay", async () => {
  const finance = new FakeGateway();
  const provider = new MockMpesaProvider();
  const first = await handleSubscriptionBillingRequest(request(initiateBody), {
    provider,
    finance,
    callbackUrl: "https://example.test/subscription/callback",
  });
  assertEquals(first.status, 202);
  assertEquals(provider.initiationCalls.length, 1);

  finance.requestStatus = "pending";
  finance.requestCheckout = "checkout-1";
  const second = await handleSubscriptionBillingRequest(request(initiateBody), {
    provider,
    finance,
    callbackUrl: "https://example.test/subscription/callback",
  });

  assertEquals(second.status, 202);
  const secondBody = await second.json() as Record<string, unknown>;
  assertEquals(secondBody.checkoutRequestId, "checkout-1");
  assertEquals(provider.initiationCalls.length, 1);
  assertEquals(finance.requestCalls, 2);
  assertEquals(finance.claimCalls, 1);
});

Deno.test("client cannot invoke the service-role confirmation boundary", async () => {
  const finance = new FakeGateway();
  const response = await handleSubscriptionBillingRequest(
    request({ ...initiateBody, action: "confirm" }),
    {
      provider: new MockMpesaProvider(),
      finance,
      callbackUrl: "https://example.test/subscription/callback",
    },
  );

  assertEquals(response.status, 400);
  assertEquals(finance.requestCalls, 0);
  assertEquals(finance.confirmCalls.length, 0);
});

Deno.test("verified evidence reaches subscription confirmation", async () => {
  const finance = new FakeGateway();
  const provider = new MockMpesaProvider();
  provider.query = { ...provider.query, amount: 12000, currency: "KES" };
  const result = await processMpesaCallback({
    attempt,
    callback: {
      authenticated: true,
      checkoutRequestId: "checkout-1",
      resultCode: "0",
      resultDesc: "Success",
      receiptNumber: "RCPT-1",
      amount: 12000,
    },
    providerEventId: "event-1",
    providerVerifiedAt: "2026-12-31T10:00:00Z",
    callbackPayload: {},
  }, { provider, finance });

  assertEquals(result.paymentId, "payment-1");
  assertEquals(finance.evidenceCalls, 1);
  assertEquals(finance.confirmCalls.length, 1);
});

Deno.test("unverified evidence cannot reach subscription confirmation", async () => {
  const finance = new FakeGateway();
  const provider = new MockMpesaProvider();
  provider.query = {
    ...provider.query,
    resultCode: "1032",
    resultDesc: "Cancelled",
  };

  let rejected = false;
  try {
    await processMpesaCallback({
      attempt,
      callback: {
        authenticated: true,
        checkoutRequestId: "checkout-1",
        resultCode: "0",
        resultDesc: "Success",
        receiptNumber: "RCPT-1",
        amount: 12000,
      },
      providerEventId: "event-1",
      providerVerifiedAt: "2026-12-31T10:00:00Z",
      callbackPayload: {},
    }, { provider, finance });
  } catch (_) {
    rejected = true;
  }

  assertEquals(rejected, true);
  assertEquals(finance.evidenceCalls, 0);
  assertEquals(finance.confirmCalls.length, 0);
});

class StubAuthenticator implements MpesaCallbackAuthenticator {
  readonly mode = "test";
  constructor(private readonly result: MpesaAuthenticatedCallback) {}

  async authenticate(): Promise<MpesaAuthenticatedCallback> {
    return this.result;
  }
}

const authenticatedCallback: MpesaAuthenticatedCallback = {
  checkoutRequestId: "checkout-1",
  resultCode: "0",
  resultDesc: "Success",
  receiptNumber: "RCPT-1",
  amount: 12000,
  callbackPayload: {},
};

Deno.test("duplicate verified confirmation remains idempotent at the boundary", async () => {
  const finance = new FakeGateway();
  const provider = new MockMpesaProvider();
  provider.query = { ...provider.query, amount: 12000, currency: "KES" };
  const deps = {
    provider,
    finance,
    authenticate: new StubAuthenticator(authenticatedCallback),
  };

  const first = await handleDarajaCallback(request({}), deps);
  const second = await handleDarajaCallback(request({}), deps);

  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(finance.confirmCalls.length, 2);
  assertEquals(finance.confirmCalls[0].attempt, "attempt-1");
  assertEquals(finance.confirmCalls[1].attempt, "attempt-1");
});

Deno.test("disabled callback authentication rejects subscription confirmation", async () => {
  const finance = new FakeGateway();
  const response = await handleDarajaCallback(request({}), {
    provider: new MockMpesaProvider(),
    finance,
    authenticate: createDarajaCallbackAuthenticator("disabled"),
  });

  assertEquals(response.status, 401);
  assertEquals(finance.confirmCalls.length, 0);
});
