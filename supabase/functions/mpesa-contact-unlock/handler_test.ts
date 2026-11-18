import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { UnconfiguredMpesaProvider } from "./contract.ts";
import { handleContactUnlockRequest } from "./handler.ts";
import type { FinanceGateway } from "./orchestrator.ts";
import { MockMpesaProvider } from "./mock_provider.ts";

class FakeFinance implements FinanceGateway {
  async claimAttempt() {
    return { status: "processing" as const };
  }

  async completeInitiation() {}

  async recordVerificationEvidence() {
    return "event-1";
  }

  async confirmPayment() {
    return "payment-1";
  }
  async loadAttemptByCheckoutRequestId() {
    return null;
  }

  async recordDefinitiveFailure() {
    return "failure-event-1";
  }
}

function request(body: unknown, method = "POST"): Request {
  return new Request("http://localhost", {
    method,
    headers: { "content-type": "application/json" },
    body: method === "POST" ? JSON.stringify(body) : undefined,
  });
}

const initiateBody = {
  action: "initiate",
  paymentAttemptId: "attempt-1",
  obligationId: "obligation-1",
  phone: "254712345678",
  amount: 150,
  currency: "KES",
};

Deno.test("handler rejects non-POST requests", async () => {
  const response = await handleContactUnlockRequest(
    request(null, "GET"),
    {
      provider: new MockMpesaProvider(),
      finance: new FakeFinance(),
      callbackUrl: "https://example.test/callback",
    },
  );
  assertEquals(response.status, 405);
});

Deno.test("handler rejects callback action from clients", async () => {
  const response = await handleContactUnlockRequest(
    request({ action: "callback" }),
    {
      provider: new MockMpesaProvider(),
      finance: new FakeFinance(),
      callbackUrl: "https://example.test/callback",
    },
  );
  assertEquals(response.status, 400);
  const body = await response.json();
  assertEquals(body.error, "unsupported_action");
});

Deno.test("handler returns 503 when provider is not configured", async () => {
  const response = await handleContactUnlockRequest(
    request(initiateBody),
    {
      provider: new UnconfiguredMpesaProvider(),
      finance: new FakeFinance(),
      callbackUrl: "https://example.test/callback",
    },
  );
  assertEquals(response.status, 503);
  const body = await response.json();
  assertEquals(body.error, "mpesa_provider_not_configured");
});

Deno.test("handler initiates with a provider implementation", async () => {
  const response = await handleContactUnlockRequest(
    request(initiateBody),
    {
      provider: new MockMpesaProvider(),
      finance: new FakeFinance(),
      callbackUrl: "https://example.test/callback",
    },
  );
  assertEquals(response.status, 202);
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.checkoutRequestId, "checkout-1");
  assertEquals(body.status, "pending");
});

Deno.test("handler rejects malformed initiation input", async () => {
  const response = await handleContactUnlockRequest(
    request({ ...initiateBody, phone: "0712345678" }),
    {
      provider: new MockMpesaProvider(),
      finance: new FakeFinance(),
      callbackUrl: "https://example.test/callback",
    },
  );
  assertEquals(response.status, 400);
});
