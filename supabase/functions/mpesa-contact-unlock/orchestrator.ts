import {
  buildFinanceVerificationEvidence,
  type FinanceVerificationEvidence,
  mapMpesaPaymentAttemptToStkPush,
  type MpesaCallbackEvidence,
  type MpesaPaymentAttempt,
  type MpesaProvider,
  MpesaProviderNotConfiguredError,
  type MpesaStkQueryResult,
} from "./contract.ts";

export type ClaimedPaymentAttempt = {
  status: "processing";
};

export interface FinanceGateway {
  claimAttempt(paymentAttemptId: string): Promise<ClaimedPaymentAttempt>;
  completeInitiation(
    paymentAttemptId: string,
    checkoutRequestId: string | null,
    failureCode?: string | null,
    failureMessage?: string | null,
  ): Promise<void>;
  recordVerificationEvidence(
    evidence: FinanceVerificationEvidence,
  ): Promise<string>;
  confirmPayment(
    paymentAttemptId: string,
    providerEventId: string,
  ): Promise<string>;
  loadAttemptByCheckoutRequestId(
    checkoutRequestId: string,
  ): Promise<MpesaPaymentAttempt | null>;
  recordDefinitiveFailure(input: {
    paymentAttemptId: string;
    providerEventId: string;
    checkoutRequestId: string;
    failureCode: string;
    failureDescription: string;
    callbackPayload: Record<string, unknown>;
    providerQueryResult: Record<string, unknown>;
    providerVerifiedAt: string;
  }): Promise<string>;
}

export class MpesaProviderRejectionError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = "MpesaProviderRejectionError";
    this.code = code;
  }
}

export class MpesaProviderUnknownOutcomeError extends Error {
  constructor(message = "mpesa_provider_outcome_unknown") {
    super(message);
    this.name = "MpesaProviderUnknownOutcomeError";
  }
}

export type InitiateMpesaPaymentInput = {
  attempt: MpesaPaymentAttempt;
  callbackUrl: string;
};

export type InitiateMpesaPaymentDeps = {
  provider: MpesaProvider;
  finance: FinanceGateway;
};

export type InitiateMpesaPaymentResult = {
  paymentAttemptId: string;
  checkoutRequestId: string;
  status: "pending";
};

/**
 * Provider-independent initiation orchestration.
 *
 * Finance owns attempt state. A definitive provider rejection is recorded as
 * failure. Unknown/network outcomes are left in `processing` for
 * reconciliation; the provider is never called twice by this function.
 */
export async function initiateMpesaPayment(
  input: InitiateMpesaPaymentInput,
  deps: InitiateMpesaPaymentDeps,
): Promise<InitiateMpesaPaymentResult> {
  if (deps.provider.isConfigured && !deps.provider.isConfigured()) {
    throw new MpesaProviderNotConfiguredError();
  }

  const stkRequest = mapMpesaPaymentAttemptToStkPush(
    input.attempt,
    input.callbackUrl,
  );

  await deps.finance.claimAttempt(input.attempt.paymentAttemptId);

  let stkResponse;
  try {
    stkResponse = await deps.provider.initiateStkPush(stkRequest);
  } catch (error) {
    if (error instanceof MpesaProviderNotConfiguredError) {
      throw error;
    }
    if (error instanceof MpesaProviderRejectionError) {
      await deps.finance.completeInitiation(
        input.attempt.paymentAttemptId,
        null,
        error.code,
        error.message,
      );
      throw error;
    }
    throw new MpesaProviderUnknownOutcomeError();
  }

  if (!stkResponse.checkoutRequestId.trim()) {
    throw new MpesaProviderUnknownOutcomeError(
      "mpesa_provider_missing_checkout_request_id",
    );
  }

  await deps.finance.completeInitiation(
    input.attempt.paymentAttemptId,
    stkResponse.checkoutRequestId,
  );

  return {
    paymentAttemptId: input.attempt.paymentAttemptId,
    checkoutRequestId: stkResponse.checkoutRequestId,
    status: "pending",
  };
}

export type VerifyMpesaPaymentInput = {
  attempt: MpesaPaymentAttempt;
  callback: MpesaCallbackEvidence;
  providerEventId: string;
  providerVerifiedAt: string;
  callbackPayload: Record<string, unknown>;
  providerQueryResult?: Record<string, unknown>;
};

export type VerifyMpesaPaymentDeps = {
  provider: MpesaProvider;
  finance: FinanceGateway;
};

export type VerifyMpesaPaymentResult = {
  paymentAttemptId: string;
  providerEventId: string;
  paymentId: string;
};

/**
 * Callback/query orchestration. The provider adapter must authenticate the
 * callback before invoking this function. Finance records the evidence and
 * owns confirmation/finalization; this function only invokes that boundary.
 */
export async function processMpesaCallback(
  input: VerifyMpesaPaymentInput,
  deps: VerifyMpesaPaymentDeps,
): Promise<VerifyMpesaPaymentResult> {
  if (!input.attempt.checkoutRequestId) {
    throw new Error("missing_checkout_request_id");
  }

  const query: MpesaStkQueryResult = await deps.provider.queryStkPush(
    input.attempt.checkoutRequestId,
  );

  const evidence = buildFinanceVerificationEvidence({
    attempt: input.attempt,
    callback: input.callback,
    query,
    providerEventId: input.providerEventId,
    providerVerifiedAt: input.providerVerifiedAt,
    callbackPayload: input.callbackPayload,
    providerQueryResult: query.raw ?? input.providerQueryResult ?? {},
  });

  const providerEventId = await deps.finance.recordVerificationEvidence(
    evidence,
  );
  const paymentId = await deps.finance.confirmPayment(
    evidence.paymentAttemptId,
    providerEventId,
  );

  return {
    paymentAttemptId: evidence.paymentAttemptId,
    providerEventId,
    paymentId,
  };
}

export type MpesaFailureInput = {
  attempt: MpesaPaymentAttempt;
  callback: MpesaCallbackEvidence;
  providerEventId: string;
  providerVerifiedAt: string;
  callbackPayload: Record<string, unknown>;
};

export type MpesaFailureResult = {
  paymentAttemptId: string;
  providerEventId: string;
};

/**
 * Verified definitive-failure orchestration. Finance remains responsible for
 * the failure-code allowlist and all state transitions.
 */
export async function processMpesaFailure(
  input: MpesaFailureInput,
  deps: VerifyMpesaPaymentDeps,
): Promise<MpesaFailureResult> {
  if (!input.attempt.checkoutRequestId) {
    throw new Error("missing_checkout_request_id");
  }
  if (!input.callback.authenticated) {
    throw new Error("callback_not_authenticated");
  }

  const query = await deps.provider.queryStkPush(
    input.attempt.checkoutRequestId,
  );
  const providerEventId = await deps.finance.recordDefinitiveFailure({
    paymentAttemptId: input.attempt.paymentAttemptId,
    providerEventId: input.providerEventId,
    checkoutRequestId: input.attempt.checkoutRequestId,
    failureCode: input.callback.resultCode,
    failureDescription: input.callback.resultDesc,
    callbackPayload: input.callbackPayload,
    providerQueryResult: query.raw ?? {},
    providerVerifiedAt: input.providerVerifiedAt,
  });

  return {
    paymentAttemptId: input.attempt.paymentAttemptId,
    providerEventId,
  };
}
