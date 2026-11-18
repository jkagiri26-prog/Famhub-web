import type {
  MpesaProvider,
  MpesaStkPushRequest,
  MpesaStkPushResponse,
  MpesaStkQueryResult,
} from "./contract.ts";
import {
  MpesaProviderRejectionError,
  MpesaProviderUnknownOutcomeError,
} from "./orchestrator.ts";
import type { DarajaConfig } from "./daraja_config.ts";

type FetchFn = (input: string, init?: RequestInit) => Promise<Response>;

type TokenState = {
  value: string;
  expiresAt: number;
};

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function formatTimestamp(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${
    pad(date.getUTCDate())
  }${pad(date.getUTCHours())}${pad(date.getUTCMinutes())}${
    pad(date.getUTCSeconds())
  }`;
}

function metadataValue(
  data: Record<string, unknown>,
  name: string,
): string | number | undefined {
  const metadata = asRecord(data.CallbackMetadata);
  const items = metadata.Item;
  if (!Array.isArray(items)) return undefined;
  for (const item of items) {
    const row = asRecord(item);
    if (row.Name === name) {
      return row.Value as string | number | undefined;
    }
  }
  return undefined;
}

export class DarajaProvider implements MpesaProvider {
  private token?: TokenState;

  constructor(
    private readonly config: DarajaConfig,
    private readonly fetchFn: FetchFn = fetch,
    private readonly now: () => number = Date.now,
    private readonly requestTimeoutMs = 30_000,
  ) {}

  isConfigured(): boolean {
    return true;
  }

  async initiateStkPush(
    request: MpesaStkPushRequest,
  ): Promise<MpesaStkPushResponse> {
    const token = await this.accessToken();
    const timestamp = formatTimestamp(new Date(this.now()));
    const password = btoa(
      `${this.config.shortCode}${this.config.passkey}${timestamp}`,
    );

    const response = await this.post(
      this.config.stkPushPath,
      token,
      {
        BusinessShortCode: this.config.shortCode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: "CustomerPayBillOnline",
        Amount: Math.round(request.amount),
        PartyA: request.phone,
        PartyB: this.config.shortCode,
        PhoneNumber: request.phone,
        CallBackURL: request.callbackUrl,
        AccountReference: request.accountReference,
        TransactionDesc: request.transactionDesc,
      },
    );

    const data = asRecord(response.data);
    const responseCode = String(data.ResponseCode ?? "");
    if (responseCode !== "0") {
      throw new MpesaProviderRejectionError(
        responseCode || "stk_push_rejected",
        String(
          data.ResponseDescription ?? data.errorMessage ?? "STK Push rejected",
        ),
      );
    }

    const checkoutRequestId = String(data.CheckoutRequestID ?? "").trim();
    if (!checkoutRequestId) {
      throw new MpesaProviderUnknownOutcomeError(
        "daraja_missing_checkout_request_id",
      );
    }

    return {
      merchantRequestId: String(data.MerchantRequestID ?? ""),
      checkoutRequestId,
      responseCode,
      responseDescription: String(data.ResponseDescription ?? ""),
      customerMessage: data.CustomerMessage
        ? String(data.CustomerMessage)
        : undefined,
    };
  }

  async queryStkPush(checkoutRequestId: string): Promise<MpesaStkQueryResult> {
    const token = await this.accessToken();
    const timestamp = formatTimestamp(new Date(this.now()));
    const password = btoa(
      `${this.config.shortCode}${this.config.passkey}${timestamp}`,
    );

    const response = await this.post(
      this.config.stkQueryPath,
      token,
      {
        BusinessShortCode: this.config.shortCode,
        Password: password,
        Timestamp: timestamp,
        CheckoutRequestID: checkoutRequestId,
      },
    );

    const data = asRecord(response.data);
    const resultCode = String(data.ResultCode ?? "");
    if (!resultCode) {
      throw new MpesaProviderUnknownOutcomeError(
        "daraja_missing_query_result_code",
      );
    }

    return {
      checkoutRequestId: String(data.CheckoutRequestID ?? checkoutRequestId),
      resultCode,
      resultDesc: String(data.ResultDesc ?? ""),
      receiptNumber: metadataValue(data, "MpesaReceiptNumber") as
        | string
        | undefined,
      amount: metadataValue(data, "Amount") as number | undefined,
      currency: data.Currency ? String(data.Currency) : undefined,
      raw: data,
    };
  }

  private async accessToken(): Promise<string> {
    const now = this.now();
    if (this.token && this.token.expiresAt > now + 30_000) {
      return this.token.value;
    }

    const basic = btoa(
      `${this.config.consumerKey}:${this.config.consumerSecret}`,
    );
    let response: { status: number; data: unknown };
    try {
      response = await this.post(
        this.config.oauthPath,
        null,
        { grant_type: "client_credentials" },
        { Authorization: `Basic ${basic}` },
      );
    } catch (_) {
      throw new MpesaProviderUnknownOutcomeError(
        "daraja_oauth_outcome_unknown",
      );
    }
    const data = asRecord(response.data);
    const token = String(data.access_token ?? "").trim();
    if (!token) {
      throw new MpesaProviderUnknownOutcomeError("daraja_oauth_token_missing");
    }
    const expiresIn = Number(data.expires_in ?? 0);
    this.token = {
      value: token,
      expiresAt: now + (Number.isFinite(expiresIn) ? expiresIn * 1000 : 0),
    };
    return token;
  }

  private async post(
    path: string,
    token: string | null,
    body: Record<string, unknown>,
    extraHeaders: Record<string, string> = {},
  ): Promise<{ status: number; data: unknown }> {
    let response: Response;
    try {
      response = await this.fetchFn(`${this.config.baseUrl}${path}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...extraHeaders,
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(this.requestTimeoutMs),
      });
    } catch (_) {
      throw new MpesaProviderUnknownOutcomeError(
        "daraja_network_outcome_unknown",
      );
    }

    let data: unknown;
    try {
      data = await response.json();
    } catch (_) {
      throw new MpesaProviderUnknownOutcomeError("daraja_invalid_response");
    }

    if (!response.ok) {
      // HTTP/auth/rate-limit errors do not prove a definitive payment rejection.
      // Leave the Finance attempt processing for reconciliation.
      throw new MpesaProviderUnknownOutcomeError("daraja_http_outcome_unknown");
    }

    return { status: response.status, data };
  }
}
