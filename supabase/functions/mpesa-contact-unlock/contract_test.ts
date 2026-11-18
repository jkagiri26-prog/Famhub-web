import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildFinanceVerificationEvidence,
  mapMpesaPaymentAttemptToStkPush,
  type MpesaPaymentAttempt,
} from "./contract.ts";

const attempt: MpesaPaymentAttempt = {
  paymentAttemptId: "attempt-1",
  checkoutRequestId: "checkout-1",
  phone: "254712345678",
  amount: 150,
  currency: "KES",
  accountReference: "order-42",
  transactionDesc: "Vunio order 42",
};

Deno.test("maps a payment attempt to an STK request", () => {
  const request = mapMpesaPaymentAttemptToStkPush(
    attempt,
    "https://example.test/mpesa/callback",
  );
  assertEquals(request.phone, "254712345678");
  assertEquals(request.amount, 150);
  assertEquals(request.accountReference, "order-42");
  assertEquals(request.transactionDesc, "Vunio order 42");
});

Deno.test("rejects invalid phone, amount, currency, or callback", () => {
  assertThrows(() =>
    mapMpesaPaymentAttemptToStkPush(
      { ...attempt, phone: "0712345678" },
      "https://example.test/callback",
    )
  );
  assertThrows(() =>
    mapMpesaPaymentAttemptToStkPush(
      { ...attempt, amount: 0 },
      "https://example.test/callback",
    )
  );
  assertThrows(() =>
    mapMpesaPaymentAttemptToStkPush(
      { ...attempt, currency: "USD" as "KES" },
      "https://example.test/callback",
    )
  );
  assertThrows(() => mapMpesaPaymentAttemptToStkPush(attempt, " "));
});

Deno.test("builds evidence only from authenticated matching callback and query", () => {
  const evidence = buildFinanceVerificationEvidence({
    attempt,
    callback: {
      authenticated: true,
      checkoutRequestId: "checkout-1",
      resultCode: "0",
      resultDesc: "Success",
      receiptNumber: "RCPT-1",
      amount: 150,
    },
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
    callbackPayload: { Body: {} },
    providerQueryResult: { ResultCode: "0" },
  });

  assertEquals(evidence.paymentAttemptId, "attempt-1");
  assertEquals(evidence.providerReference, "RCPT-1");
  assertEquals(evidence.verifiedAmount, 150);
  assertEquals(evidence.callbackAuthenticationSucceeded, true);
});

Deno.test("rejects unauthenticated, failed, mismatched, or incomplete evidence", () => {
  const base = {
    attempt,
    callback: {
      authenticated: true,
      checkoutRequestId: "checkout-1",
      resultCode: "0",
      resultDesc: "Success",
      receiptNumber: "RCPT-1",
      amount: 150,
    },
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
    callbackPayload: { Body: {} },
    providerQueryResult: { ResultCode: "0" },
  };

  assertThrows(() =>
    buildFinanceVerificationEvidence({
      ...base,
      callback: { ...base.callback, authenticated: false },
    })
  );
  assertThrows(() =>
    buildFinanceVerificationEvidence({
      ...base,
      query: { ...base.query, resultCode: "1032" },
    })
  );
  assertThrows(() =>
    buildFinanceVerificationEvidence({
      ...base,
      query: { ...base.query, checkoutRequestId: "other" },
    })
  );
  assertThrows(() =>
    buildFinanceVerificationEvidence({
      ...base,
      callback: { ...base.callback, receiptNumber: undefined },
    })
  );
  assertThrows(() =>
    buildFinanceVerificationEvidence({
      ...base,
      query: { ...base.query, amount: 149 },
    })
  );
});
