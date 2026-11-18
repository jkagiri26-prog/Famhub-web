import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DarajaProvider } from "./daraja_provider.ts";
import type { DarajaConfig } from "./daraja_config.ts";
import {
  MpesaProviderRejectionError,
  MpesaProviderUnknownOutcomeError,
} from "./orchestrator.ts";

const config: DarajaConfig = {
  consumerKey: "fixture",
  consumerSecret: "fixture",
  passkey: "fixture",
  shortCode: "123456",
  environment: "sandbox",
  baseUrl: "https://sandbox.example.test",
  oauthPath: "/oauth",
  stkPushPath: "/stkpush",
  stkQueryPath: "/stkquery",
  callbackUrl: "https://example.test/callback",
};

type Call = { url: string; init?: RequestInit; body?: Record<string, unknown> };

function fakeFetch(
  handler: (call: Call) => Response | Promise<Response>,
): { fetchFn: typeof fetch; calls: Call[] } {
  const calls: Call[] = [];
  return {
    calls,
    fetchFn: (async (input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      const body = init?.body ? JSON.parse(String(init.body)) : undefined;
      const call = { url, init, body };
      calls.push(call);
      return await handler(call);
    }) as typeof fetch,
  };
}

Deno.test("daraja authenticates, initiates, and maps checkout response", async () => {
  const { fetchFn, calls } = fakeFetch((call) => {
    if (call.url.endsWith("/oauth")) {
      return new Response(
        JSON.stringify({
          access_token: "token-1",
          expires_in: 3599,
        }),
        { status: 200 },
      );
    }
    return new Response(
      JSON.stringify({
        MerchantRequestID: "merchant-1",
        CheckoutRequestID: "checkout-1",
        ResponseCode: "0",
        ResponseDescription: "Success",
        CustomerMessage: "Enter PIN",
      }),
      { status: 200 },
    );
  });
  const provider = new DarajaProvider(config, fetchFn, () => 1_700_000_000_000);

  const result = await provider.initiateStkPush({
    phone: "254712345678",
    amount: 150.4,
    accountReference: "order-42",
    transactionDesc: "Vunio order 42",
    callbackUrl: "https://example.test/callback",
  });

  assertEquals(result.checkoutRequestId, "checkout-1");
  assertEquals(result.customerMessage, "Enter PIN");
  assertEquals(calls[0].url, "https://sandbox.example.test/oauth");
  assertEquals(
    (calls[0].init?.headers as Record<string, string>).Authorization,
    `Basic ${btoa("fixture:fixture")}`,
  );
  assertEquals(calls[1].body?.Amount, 150);
  assertEquals(calls[1].body?.AccountReference, "order-42");
  assertEquals(calls[1].body?.CallBackURL, "https://example.test/callback");
  assertEquals(
    (calls[1].init?.headers as Record<string, string>).Authorization,
    "Bearer token-1",
  );
});

Deno.test("daraja caches the OAuth token until near expiry", async () => {
  let oauthCalls = 0;
  const { fetchFn } = fakeFetch((call) => {
    if (call.url.endsWith("/oauth")) {
      oauthCalls++;
      return new Response(
        JSON.stringify({
          access_token: "token-1",
          expires_in: 3600,
        }),
        { status: 200 },
      );
    }
    return new Response(
      JSON.stringify({
        MerchantRequestID: "merchant-1",
        CheckoutRequestID: "checkout-1",
        ResponseCode: "0",
        ResponseDescription: "Success",
      }),
      { status: 200 },
    );
  });
  const provider = new DarajaProvider(config, fetchFn, () => 1_700_000_000_000);
  const request = {
    phone: "254712345678",
    amount: 150,
    accountReference: "order-42",
    transactionDesc: "Vunio order 42",
    callbackUrl: "https://example.test/callback",
  };

  await provider.initiateStkPush(request);
  await provider.initiateStkPush(request);

  assertEquals(oauthCalls, 1);
});

Deno.test("daraja returns provider rejection codes without inventing success", async () => {
  const { fetchFn } = fakeFetch((call) => {
    if (call.url.endsWith("/oauth")) {
      return new Response(
        JSON.stringify({
          access_token: "token-1",
          expires_in: 3599,
        }),
        { status: 200 },
      );
    }
    return new Response(
      JSON.stringify({
        ResponseCode: "1032",
        ResponseDescription: "Request cancelled by user",
      }),
      { status: 200 },
    );
  });
  const provider = new DarajaProvider(config, fetchFn, () => 1_700_000_000_000);

  await assertRejects(
    () =>
      provider.initiateStkPush({
        phone: "254712345678",
        amount: 150,
        accountReference: "order-42",
        transactionDesc: "Vunio order 42",
        callbackUrl: "https://example.test/callback",
      }),
    MpesaProviderRejectionError,
    "Request cancelled by user",
  );
});

Deno.test("daraja maps query result and metadata", async () => {
  const { fetchFn } = fakeFetch((call) => {
    if (call.url.endsWith("/oauth")) {
      return new Response(
        JSON.stringify({
          access_token: "token-1",
          expires_in: 3599,
        }),
        { status: 200 },
      );
    }
    return new Response(
      JSON.stringify({
        CheckoutRequestID: "checkout-1",
        ResultCode: "0",
        ResultDesc: "Success",
        CallbackMetadata: {
          Item: [
            { Name: "MpesaReceiptNumber", Value: "RCPT123" },
            { Name: "Amount", Value: 150 },
          ],
        },
      }),
      { status: 200 },
    );
  });
  const provider = new DarajaProvider(config, fetchFn, () => 1_700_000_000_000);

  const result = await provider.queryStkPush("checkout-1");

  assertEquals(result.checkoutRequestId, "checkout-1");
  assertEquals(result.receiptNumber, "RCPT123");
  assertEquals(result.amount, 150);
});

Deno.test("daraja treats network failures as unknown outcomes", async () => {
  const { fetchFn } = fakeFetch(() => {
    throw new Error("network down");
  });
  const provider = new DarajaProvider(config, fetchFn, () => 1_700_000_000_000);

  await assertRejects(
    () =>
      provider.initiateStkPush({
        phone: "254712345678",
        amount: 150,
        accountReference: "order-42",
        transactionDesc: "Vunio order 42",
        callbackUrl: "https://example.test/callback",
      }),
    MpesaProviderUnknownOutcomeError,
  );
});

Deno.test("daraja treats missing OAuth token as an unknown outcome", async () => {
  const { fetchFn } = fakeFetch(() => new Response("{}", { status: 200 }));
  const provider = new DarajaProvider(config, fetchFn, () => 1_700_000_000_000);

  await assertRejects(
    () =>
      provider.initiateStkPush({
        phone: "254712345678",
        amount: 150,
        accountReference: "order-42",
        transactionDesc: "Vunio order 42",
        callbackUrl: "https://example.test/callback",
      }),
    MpesaProviderUnknownOutcomeError,
  );
});

Deno.test("daraja treats HTTP auth failure as an unknown outcome", async () => {
  const { fetchFn } = fakeFetch((call) => {
    if (call.url.endsWith("/oauth")) {
      return new Response(
        JSON.stringify({
          access_token: "token-1",
          expires_in: 3599,
        }),
        { status: 200 },
      );
    }
    return new Response(JSON.stringify({ errorMessage: "Unauthorized" }), {
      status: 401,
    });
  });
  const provider = new DarajaProvider(config, fetchFn, () => 1_700_000_000_000);

  await assertRejects(
    () =>
      provider.initiateStkPush({
        phone: "254712345678",
        amount: 150,
        accountReference: "order-42",
        transactionDesc: "Vunio order 42",
        callbackUrl: "https://example.test/callback",
      }),
    MpesaProviderUnknownOutcomeError,
  );
});

Deno.test("daraja errors never expose credentials", async () => {
  const { fetchFn } = fakeFetch(() => {
    throw new Error("network down");
  });
  const provider = new DarajaProvider(config, fetchFn, () => 1_700_000_000_000);

  try {
    await provider.initiateStkPush({
      phone: "254712345678",
      amount: 150,
      accountReference: "order-42",
      transactionDesc: "Vunio order 42",
      callbackUrl: "https://example.test/callback",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    assertEquals(message.includes("fixture"), false);
    assertEquals(message.includes("fixture-key"), false);
    assertEquals(message.includes("token"), false);
    return;
  }
  throw new Error("expected provider failure");
});
