// ============================================================================
// Generic M-Pesa provider boundary
// ----------------------------------------------------------------------------
// This module deliberately contains no Daraja endpoint, credentials, or HTTP
// client. A real provider adapter must implement MpesaProvider and map its
// authenticated callback plus independent STK Query result into
// FinanceVerificationEvidence. No unverified callback can produce evidence.
// ============================================================================

export type MpesaPaymentAttempt = {
  paymentAttemptId: string;
  checkoutRequestId?: string;
  phone: string;
  accountReference?: string;
  transactionDesc?: string;
  amount: number;
  currency: "KES";
};

export type MpesaStkPushRequest = {
  phone: string;
  amount: number;
  accountReference: string;
  transactionDesc: string;
  callbackUrl: string;
};

export type MpesaStkPushResponse = {
  merchantRequestId: string;
  checkoutRequestId: string;
  responseCode: string;
  responseDescription: string;
  customerMessage?: string;
};

export type MpesaStkQueryResult = {
  checkoutRequestId: string;
  resultCode: string;
  resultDesc: string;
  receiptNumber?: string;
  amount?: number;
  currency?: string;
  raw?: Record<string, unknown>;
};

export type MpesaCallbackEvidence = {
  authenticated: boolean;
  checkoutRequestId: string;
  resultCode: string;
  resultDesc: string;
  receiptNumber?: string;
  amount?: number;
};

export type FinanceVerificationEvidence = {
  paymentAttemptId: string;
  providerEventId: string;
  providerReference: string;
  verifiedAmount: number;
  verifiedCurrency: "KES";
  callbackPayload: Record<string, unknown>;
  providerQueryResult: Record<string, unknown>;
  callbackAuthenticationSucceeded: true;
  providerVerifiedAt: string;
};

export interface MpesaProvider {
  isConfigured?(): boolean;
  initiateStkPush(request: MpesaStkPushRequest): Promise<MpesaStkPushResponse>;
  queryStkPush(checkoutRequestId: string): Promise<MpesaStkQueryResult>;
}

export class MpesaProviderNotConfiguredError extends Error {
  constructor() {
    super("mpesa_provider_not_configured");
    this.name = "MpesaProviderNotConfiguredError";
  }
}

export class UnconfiguredMpesaProvider implements MpesaProvider {
  isConfigured(): boolean {
    return false;
  }

  initiateStkPush(): Promise<MpesaStkPushResponse> {
    return Promise.reject(new MpesaProviderNotConfiguredError());
  }

  queryStkPush(): Promise<MpesaStkQueryResult> {
    return Promise.reject(new MpesaProviderNotConfiguredError());
  }
}

export function mapMpesaPaymentAttemptToStkPush(
  attempt: MpesaPaymentAttempt,
  callbackUrl: string,
): MpesaStkPushRequest {
  if (!/^2547\d{8}$/.test(attempt.phone)) {
    throw new Error("invalid_mpesa_phone");
  }
  if (!Number.isFinite(attempt.amount) || attempt.amount <= 0) {
    throw new Error("invalid_mpesa_amount");
  }
  if (attempt.currency !== "KES") {
    throw new Error("unsupported_mpesa_currency");
  }
  if (!callbackUrl.trim()) {
    throw new Error("missing_mpesa_callback_url");
  }
  if (!attempt.accountReference?.trim() || !attempt.transactionDesc?.trim()) {
    throw new Error("missing_mpesa_reference_or_description");
  }

  return {
    phone: attempt.phone,
    amount: attempt.amount,
    accountReference: attempt.accountReference!,
    transactionDesc: attempt.transactionDesc!,
    callbackUrl,
  };
}

/**
 * Converts only verified callback + independent STK Query evidence into the
 * exact inputs for finance.record_mpesa_verification_evidence.
 */
export function buildFinanceVerificationEvidence(input: {
  attempt: MpesaPaymentAttempt;
  callback: MpesaCallbackEvidence;
  query: MpesaStkQueryResult;
  providerEventId: string;
  providerVerifiedAt: string;
  callbackPayload: Record<string, unknown>;
  providerQueryResult: Record<string, unknown>;
}): FinanceVerificationEvidence {
  const { attempt, callback, query } = input;

  if (!callback.authenticated) {
    throw new Error("unauthenticated_mpesa_callback");
  }
  if (callback.resultCode !== "0" || query.resultCode !== "0") {
    throw new Error("mpesa_payment_not_successful");
  }
  if (!attempt.checkoutRequestId) {
    throw new Error("missing_checkout_request_id");
  }
  if (
    callback.checkoutRequestId !== attempt.checkoutRequestId ||
    query.checkoutRequestId !== attempt.checkoutRequestId
  ) {
    throw new Error("mpesa_checkout_request_mismatch");
  }
  if (!callback.receiptNumber) {
    throw new Error("missing_mpesa_receipt");
  }
  if (query.receiptNumber && query.receiptNumber !== callback.receiptNumber) {
    throw new Error("mpesa_receipt_mismatch");
  }
  if (
    callback.amount !== attempt.amount ||
    (query.amount !== undefined && query.amount !== attempt.amount) ||
    (query.currency !== undefined && query.currency !== "KES")
  ) {
    throw new Error("mpesa_amount_or_currency_mismatch");
  }
  if (!input.providerEventId.trim() || !input.providerVerifiedAt.trim()) {
    throw new Error("missing_mpesa_verification_metadata");
  }

  return {
    paymentAttemptId: attempt.paymentAttemptId,
    providerEventId: input.providerEventId,
    providerReference: callback.receiptNumber,
    verifiedAmount: callback.amount!,
    verifiedCurrency: "KES",
    callbackPayload: input.callbackPayload,
    providerQueryResult: input.providerQueryResult,
    callbackAuthenticationSucceeded: true,
    providerVerifiedAt: input.providerVerifiedAt,
  };
}
