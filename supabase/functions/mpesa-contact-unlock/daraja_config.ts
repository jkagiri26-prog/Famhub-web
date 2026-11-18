export type DarajaEnvironment = "sandbox" | "production";

export type DarajaConfig = {
  consumerKey: string;
  consumerSecret: string;
  passkey: string;
  shortCode: string;
  environment: DarajaEnvironment;
  baseUrl: string;
  oauthPath: string;
  stkPushPath: string;
  stkQueryPath: string;
  callbackUrl: string;
};

export type DarajaConfigResult =
  | { status: "configured"; config: DarajaConfig; missing: []; malformed: [] }
  | { status: "missing"; config: null; missing: string[]; malformed: [] }
  | { status: "malformed"; config: null; missing: []; malformed: string[] };

const REQUIRED_ENV = [
  "DARAJA_CONSUMER_KEY",
  "DARAJA_CONSUMER_SECRET",
  "DARAJA_PASSKEY",
  "DARAJA_SHORT_CODE",
  "DARAJA_ENVIRONMENT",
  "DARAJA_BASE_URL",
  "DARAJA_OAUTH_PATH",
  "DARAJA_STK_PUSH_PATH",
  "DARAJA_STK_QUERY_PATH",
  "DARAJA_CALLBACK_URL",
] as const;

function validHttpsUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && url.hostname.length > 0 &&
      !url.username && !url.password;
  } catch (_) {
    return false;
  }
}

function validPath(value: string): boolean {
  return value.startsWith("/") && !value.startsWith("//") &&
    !/\s/.test(value);
}

/**
 * Loads only server-side Daraja configuration. Results contain variable names,
 * never values, so secrets cannot leak through validation errors or logs.
 */
export function loadDarajaConfig(
  env: (key: string) => string | undefined,
): DarajaConfigResult {
  const missing = REQUIRED_ENV.filter((key) => !(env(key) ?? "").trim());
  if (missing.length > 0) {
    return { status: "missing", config: null, missing, malformed: [] };
  }

  const environment = env("DARAJA_ENVIRONMENT")!.trim();
  const baseUrl = env("DARAJA_BASE_URL")!.trim().replace(/\/+$/, "");
  const callbackUrl = env("DARAJA_CALLBACK_URL")!.trim();
  const shortCode = env("DARAJA_SHORT_CODE")!.trim();
  const oauthPath = env("DARAJA_OAUTH_PATH")!.trim();
  const stkPushPath = env("DARAJA_STK_PUSH_PATH")!.trim();
  const stkQueryPath = env("DARAJA_STK_QUERY_PATH")!.trim();

  const malformed: string[] = [];
  if (environment !== "sandbox" && environment !== "production") {
    malformed.push("DARAJA_ENVIRONMENT");
  }
  if (!validHttpsUrl(baseUrl)) malformed.push("DARAJA_BASE_URL");
  if (!validHttpsUrl(callbackUrl)) malformed.push("DARAJA_CALLBACK_URL");
  if (!/^\d{5,10}$/.test(shortCode)) malformed.push("DARAJA_SHORT_CODE");
  if (!validPath(oauthPath)) malformed.push("DARAJA_OAUTH_PATH");
  if (!validPath(stkPushPath)) malformed.push("DARAJA_STK_PUSH_PATH");
  if (!validPath(stkQueryPath)) malformed.push("DARAJA_STK_QUERY_PATH");

  if (malformed.length > 0) {
    return { status: "malformed", config: null, missing: [], malformed };
  }

  return {
    status: "configured",
    config: {
      consumerKey: env("DARAJA_CONSUMER_KEY")!.trim(),
      consumerSecret: env("DARAJA_CONSUMER_SECRET")!.trim(),
      passkey: env("DARAJA_PASSKEY")!.trim(),
      shortCode,
      environment: environment as DarajaEnvironment,
      baseUrl,
      oauthPath,
      stkPushPath,
      stkQueryPath,
      callbackUrl,
    },
    missing: [],
    malformed: [],
  };
}
