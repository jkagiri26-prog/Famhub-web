import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildFinanceVerificationEvidence,
  type MpesaPaymentAttempt,
} from "./contract.ts";
import {
  type FinanceGateway,
  initiateMpesaPayment,
  MpesaProviderRejectionError,
  MpesaProviderUnknownOutcomeError,
  processMpesaCallback,
} from "./orchestrator.ts";
import { MockMpesaProvider } from "./mock_provider.ts";

const initiationAttempt: MpesaPaymentAttempt = {
  paymentAttemptId: "attempt-1",
  phone: "254712345678",
  amount: 150,
  currency: "KES",
  accountReference: "contact-unlock:obligation-1",
  transactionDesc: "Vunio contact unlock",
};

const evidenceAttempt: MpesaPaymentAttempt = {
  ...initiationAttempt,
  checkoutRequestId: "checkout-1",
};

class FakeFinance implements FinanceGateway {
  claimCalls: string[] = [];
  completionCalls: Array<{
    id: string;
    checkout: string | null;
    code?: string | null;
    message?: string | null;
  }> = [];
  evidenceCalls: number = 0;
  confirmCalls: Array<{ attempt: string; event: string }> = [];

  async claimAttempt(paymentAttemptId: string) {
    this.claimCalls.push(paymentAttemptId);
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

  async confirmPayment(attempt: string, event: string) {
    this.confirmCalls.push({ attempt, event });
    return "payment-1";
  }
  async loadAttemptByCheckoutRequestId() {
    return null;
  }

  async recordDefinitiveFailure() {
    return "failure-event-1";
  }
}

function callback(overrides: Record<string, unknown> = {}) {
  return {
    authenticated: true,
    checkoutRequestId: "checkout-1",
    resultCode: "0",
    resultDesc: "Success",
    receiptNumber: "RCPT-1",
    amount: 150,
    ...overrides,
  };
}

Deno.test("initiation claims, maps, initiates, and records pending state", async () => {
  const provider = new MockMpesaProvider();
  const finance = new FakeFinance();
  const result = await initiateMpesaPayment(
    {
      attempt: initiationAttempt,
      callbackUrl: "https://example.test/callback",
    },
    { provider, finance },
  );

  assertEquals(finance.claimCalls, ["attempt-1"]);
  assertEquals(provider.initiationCalls.length, 1);
  assertEquals(provider.initiationCalls[0].phone, "254712345678");
  assertEquals(
    provider.initiationCalls[0].accountReference,
    "contact-unlock:obligation-1",
  );
  assertEquals(finance.completionCalls, [
    { id: "attempt-1", checkout: "checkout-1", code: null, message: null },
  ]);
  assertEquals(result.status, "pending");
  assertEquals(result.checkoutRequestId, "checkout-1");
});

Deno.test("definitive provider rejection records failure and rethrows", async () => {
  const provider = new MockMpesaProvider();
  provider.initiationError = new MpesaProviderRejectionError(
    "1032",
    "Cancelled",
  );
  const finance = new FakeFinance();

  await assertRejects(
    () =>
      initiateMpesaPayment(
        {
          attempt: initiationAttempt,
          callbackUrl: "https://example.test/callback",
        },
        { provider, finance },
      ),
    MpesaProviderRejectionError,
  );
  assertEquals(finance.completionCalls, [
    { id: "attempt-1", checkout: null, code: "1032", message: "Cancelled" },
  ]);
});

Deno.test("unknown provider outcome leaves attempt processing", async () => {
  const provider = new MockMpesaProvider();
  provider.initiationError = new Error("network");
  const finance = new FakeFinance();

  await assertRejects(
    () =>
      initiateMpesaPayment(
        {
          attempt: initiationAttempt,
          callbackUrl: "https://example.test/callback",
        },
        { provider, finance },
      ),
    MpesaProviderUnknownOutcomeError,
  );
  assertEquals(finance.completionCalls.length, 0);
});

Deno.test("missing checkout request id is treated as unknown outcome", async () => {
  const provider = new MockMpesaProvider();
  provider.initiation.checkoutRequestId = "";
  const finance = new FakeFinance();

  await assertRejects(
    () =>
      initiateMpesaPayment(
        {
          attempt: initiationAttempt,
          callbackUrl: "https://example.test/callback",
        },
        { provider, finance },
      ),
    MpesaProviderUnknownOutcomeError,
  );
  assertEquals(finance.completionCalls.length, 0);
});

Deno.test("verified callback records evidence and confirms via Finance", async () => {
  const provider = new MockMpesaProvider();
  const finance = new FakeFinance();
  const result = await processMpesaCallback(
    {
      attempt: evidenceAttempt,
      callback: callback(),
      providerEventId: "event-1",
      providerVerifiedAt: "2026-11-16T00:00:00Z",
      callbackPayload: { Body: {} },
      providerQueryResult: { ResultCode: "0" },
    },
    { provider, finance },
  );

  assertEquals(provider.queryCalls, ["checkout-1"]);
  assertEquals(finance.evidenceCalls, 1);
  assertEquals(finance.confirmCalls, [{
    attempt: "attempt-1",
    event: "event-1",
  }]);
  assertEquals(result.paymentId, "payment-1");
});

Deno.test("failed payment is rejected before Finance evidence", async () => {
  const provider = new MockMpesaProvider();
  provider.query.resultCode = "1032";
  const finance = new FakeFinance();

  await assertRejects(
    () =>
      processMpesaCallback(
        {
          attempt: evidenceAttempt,
          callback: callback({ resultCode: "1032" }),
          providerEventId: "event-1",
          providerVerifiedAt: "2026-11-16T00:00:00Z",
          callbackPayload: {},
          providerQueryResult: {},
        },
        { provider, finance },
      ),
    Error,
    "mpesa_payment_not_successful",
  );
  assertEquals(finance.evidenceCalls, 0);
  assertEquals(finance.confirmCalls.length, 0);
});

Deno.test("mismatched checkout, receipt, amount, currency, or missing evidence is rejected", () => {
  const base = {
    attempt: evidenceAttempt,
    callback: callback(),
    query: {
      checkoutRequestId: "checkout-1",
      resultCode: "0",
      resultDesc: "Success",
      receiptNumber: "RCPT-1",
      amount: 150,
      currency: "KES",
    },
    providerEventId: "event-1",
    providerVerifiedAt: "2026-11-16T00:00:00Z",
    callbackPayload: {},
    providerQueryResult: {},
  };

  assertThrows(() =>
    buildFinanceVerificationEvidence({
      ...base,
      query: { ...base.query, checkoutRequestId: "other" },
    })
  );
  assertThrows(() =>
    buildFinanceVerificationEvidence({
      ...base,
      callback: callback({ receiptNumber: "OTHER" }),
    })
  );
  assertThrows(() =>
    buildFinanceVerificationEvidence({
      ...base,
      query: { ...base.query, amount: 149 },
    })
  );
  assertThrows(() =>
    buildFinanceVerificationEvidence({
      ...base,
      query: { ...base.query, currency: "USD" },
    })
  );
  assertThrows(() =>
    buildFinanceVerificationEvidence({
      ...base,
      callback: callback({ receiptNumber: undefined }),
    })
  );
});

Deno.test("duplicate callback and repeated query remain Finance-idempotent", async () => {
  const provider = new MockMpesaProvider();
  const finance = new FakeFinance();
  const input = {
    attempt: evidenceAttempt,
    callback: callback(),
    providerEventId: "event-1",
    providerVerifiedAt: "2026-11-16T00:00:00Z",
    callbackPayload: { Body: {} },
    providerQueryResult: { ResultCode: "0" },
  };

  const first = await processMpesaCallback(input, { provider, finance });
  const second = await processMpesaCallback(input, { provider, finance });

  assertEquals(first.paymentId, second.paymentId);
  assertEquals(provider.queryCalls, ["checkout-1", "checkout-1"]);
  assertEquals(finance.evidenceCalls, 2);
  assertEquals(finance.confirmCalls.length, 2);
});
