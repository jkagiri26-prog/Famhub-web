import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { loadDarajaConfig } from "./daraja_config.ts";

const completeEnv: Record<string, string> = {
  DARAJA_CONSUMER_KEY: "fixture",
  DARAJA_CONSUMER_SECRET: "fixture",
  DARAJA_PASSKEY: "fixture",
  DARAJA_SHORT_CODE: "123456",
  DARAJA_ENVIRONMENT: "sandbox",
  DARAJA_BASE_URL: "https://sandbox.example.test/",
  DARAJA_OAUTH_PATH: "/oauth/v1/generate",
  DARAJA_STK_PUSH_PATH: "/mpesa/stkpush/v1/processrequest",
  DARAJA_STK_QUERY_PATH: "/mpesa/stkpushquery/v1/query",
  DARAJA_CALLBACK_URL: "https://example.test/mpesa/callback",
};

function envFrom(values: Record<string, string>) {
  return (key: string) => values[key];
}

Deno.test("daraja config distinguishes missing configuration", () => {
  const result = loadDarajaConfig(() => undefined);
  assertEquals(result.status, "missing");
  assertEquals(result.config, null);
  assertEquals(result.missing.length, 10);
  assertEquals(result.malformed, []);
});

Deno.test("daraja config distinguishes malformed configuration", () => {
  const result = loadDarajaConfig(envFrom({
    ...completeEnv,
    DARAJA_ENVIRONMENT: "staging",
    DARAJA_BASE_URL: "not-a-url",
    DARAJA_SHORT_CODE: "abc",
    DARAJA_OAUTH_PATH: "oauth",
    DARAJA_CALLBACK_URL: "http://example.test/callback",
  }));

  assertEquals(result.status, "malformed");
  assertEquals(result.config, null);
  assertEquals(result.missing, []);
  assertEquals(result.malformed, [
    "DARAJA_ENVIRONMENT",
    "DARAJA_BASE_URL",
    "DARAJA_CALLBACK_URL",
    "DARAJA_SHORT_CODE",
    "DARAJA_OAUTH_PATH",
  ]);
});

Deno.test("daraja config accepts a complete environment-driven provider", () => {
  const result = loadDarajaConfig(envFrom(completeEnv));
  assertEquals(result.status, "configured");
  assertEquals(result.config?.environment, "sandbox");
  assertEquals(result.config?.baseUrl, "https://sandbox.example.test");
  assertEquals(
    result.config?.callbackUrl,
    "https://example.test/mpesa/callback",
  );
  assertEquals(result.config?.shortCode, "123456");
});

Deno.test("configuration validation never exposes secret values", () => {
  const result = loadDarajaConfig(envFrom({
    ...completeEnv,
    DARAJA_BASE_URL: "not-a-url",
  }));
  const serialized = JSON.stringify(result);
  assertEquals(serialized.includes("fixture"), false);
  assertEquals(serialized.includes("passkey"), false);
  assertEquals(serialized.includes("consumer"), false);
});
