import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { MpesaPaymentAttempt } from "./contract.ts";
import type { FinanceGateway } from "./orchestrator.ts";
import { handleDarajaCallback } from "./daraja_callback.ts";
import { MockMpesaProvider } from "./mock_provider.ts";
import {
  type MpesaAuthenticatedCallback,
  MpesaCallbackAuthConfigurationError,
  MpesaCallbackAuthenticationError,
  type MpesaCallbackAuthenticator,
  MpesaCallbackPayloadError,
} from "./mpesa_callback_auth.ts";

const attempt: MpesaPaymentAttempt = {
  paymentAttemptId: "attempt-1",
  checkoutRequestId: "checkout-1",
  phone: "254712345678",
  amount: 150,
  currency: "KES",
};

const authenticated: MpesaAuthenticatedCallback = {
  checkoutRequestId: "checkout-1",
  resultCode: "0",
  resultDesc: "Success",
  receiptNumber: "RCPT-1",
  amount: 150,
  callbackPayload: {
    Body: {
      stkCallback: {
        CheckoutRequestID: "checkout-1",
        ResultCode: 0,
        ResultDesc: "Success",
      },
    },
  },
};

class StubAuthenticator implements MpesaCallbackAuthenticator {
  readonly mode = "test";
  constructor(
    private readonly result: MpesaAuthenticatedCallback | Error,
  ) {}

  async authenticate(): Promise<MpesaAuthenticatedCallback> {
    if (this.result instanceof Error) throw this.result;
    return this.result;
  }
}

class FakeFinance implements FinanceGateway {
  attempt: MpesaPaymentAttempt | null = attempt;
  evidenceCalls = 0;
  confirmCalls: Array<{ attempt: string; event: string }> = [];
  failureCalls: Array<Record<string, unknown>> = [];

  async claimAttempt() {
    return { status: "processing" as const };
  }

  async completeInitiation() {}

  async recordVerificationEvidence() {
    this.evidenceCalls++;
    return "event-1";
  }

  async confirmPayment(attemptId: string, event: string) {
    this.confirmCalls.push({ attempt: attemptId, event });
    return "payment-1";
  }

  async loadAttemptByCheckoutRequestId() {
    return this.attempt;
  }

  async recordDefinitiveFailure(input: Record<string, unknown>) {
    this.failureCalls.push(input);
    return "failure-event-1";
  }
}

function request(): Request {
  return new Request("http://localhost/callback", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({}),
  });
}

Deno.test("callback rejects when authentication is disabled", async () => {
  const finance = new FakeFinance();
  const response = await handleDarajaCallback(request(), {
    provider: new MockMpesaProvider(),
    finance,
    authenticate: new StubAuthenticator(
      new MpesaCallbackAuthenticationError("callback_authentication_disabled"),
    ),
  });

  assertEquals(response.status, 401);
  assertEquals(finance.evidenceCalls, 0);
  assertEquals(finance.confirmCalls.length, 0);
});

Deno.test("callback rejects malformed payloads before Finance lookup", async () => {
  const finance = new FakeFinance();
  const response = await handleDarajaCallback(request(), {
    provider: new MockMpesaProvider(),
    finance,
    authenticate: new StubAuthenticator(
      new MpesaCallbackPayloadError("invalid_callback_payload"),
    ),
  });

  assertEquals(response.status, 400);
  assertEquals(finance.evidenceCalls, 0);
});

Deno.test("callback reports configuration errors separately", async () => {
  const finance = new FakeFinance();
  const response = await handleDarajaCallback(request(), {
    provider: new MockMpesaProvider(),
    finance,
    authenticate: new StubAuthenticator(
      new MpesaCallbackAuthConfigurationError("callback_auth_mode_missing"),
    ),
  });

  assertEquals(response.status, 503);
  assertEquals(finance.evidenceCalls, 0);
});

Deno.test("authenticated success confirms only through Finance", async () => {
  const finance = new FakeFinance();
  const provider = new MockMpesaProvider();
  const response = await handleDarajaCallback(request(), {
    provider,
    finance,
    authenticate: new StubAuthenticator(authenticated),
  });

  assertEquals(response.status, 200);
  assertEquals(finance.evidenceCalls, 1);
  assertEquals(finance.confirmCalls.length, 1);
  assertEquals(provider.queryCalls, ["checkout-1"]);
  assertEquals(finance.failureCalls.length, 0);
});

Deno.test("authenticated definitive failure records no payment confirmation", async () => {
  const finance = new FakeFinance();
  const provider = new MockMpesaProvider();
  provider.query = {
    checkoutRequestId: "checkout-1",
    resultCode: "1032",
    resultDesc: "Request cancelled by user",
    raw: {
      CheckoutRequestID: "checkout-1",
      ResponseCode: "0",
      ResultCode: "1032",
      ResultDesc: "Request cancelled by user",
    },
  };
  const response = await handleDarajaCallback(request(), {
    provider,
    finance,
    authenticate: new StubAuthenticator({
      ...authenticated,
      resultCode: "1032",
      resultDesc: "Request cancelled by user",
    }),
  });

  assertEquals(response.status, 200);
  assertEquals(finance.confirmCalls.length, 0);
  assertEquals(finance.failureCalls.length, 1);
});

Deno.test("callback rejects unknown checkout without confirming", async () => {
  const finance = new FakeFinance();
  finance.attempt = null;
  const response = await handleDarajaCallback(request(), {
    provider: new MockMpesaProvider(),
    finance,
    authenticate: new StubAuthenticator(authenticated),
  });

  assertEquals(response.status, 404);
  assertEquals(finance.confirmCalls.length, 0);
});
