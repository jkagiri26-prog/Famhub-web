import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import type {
  FinanceVerificationEvidence,
  MpesaPaymentAttempt,
} from "../mpesa-contact-unlock/contract.ts";
import type { FinanceGateway } from "../mpesa-contact-unlock/orchestrator.ts";

export type SubscriptionAttemptRequest = {
  paymentAttemptId: string;
  subscriptionCycleId: string;
  obligationId: string;
  amount: number;
  currency: "KES";
  status: string;
  checkoutRequestId: string | null;
};

export interface SubscriptionFinanceGateway extends FinanceGateway {
  requestAnnualSubscriptionMpesaAttempt(
    subscriptionCycleId: string,
    phone: string,
    idempotencyKey: string,
  ): Promise<SubscriptionAttemptRequest>;
  getAttemptState(
    paymentAttemptId: string,
  ): Promise<SubscriptionAttemptRequest>;
}

export type SupabaseSubscriptionFinanceConfig = {
  supabaseUrl: string;
  anonKey: string;
  serviceRoleKey: string;
  authorization: string | null;
};

function asRow(value: unknown): Record<string, unknown> | null {
  if (Array.isArray(value)) {
    return value.length > 0 && typeof value[0] === "object" && value[0] !== null
      ? value[0] as Record<string, unknown>
      : null;
  }
  return typeof value === "object" && value !== null
    ? value as Record<string, unknown>
    : null;
}

/**
 * Server-side subscription Finance boundary.
 *
 * The caller JWT is used only for the authenticated subscription-attempt RPC
 * and the existing Finance claim RPC. Finalization, evidence recording and
 * subscription activation use the service-role client and are never exposed
 * to Flutter.
 */
export function createSubscriptionFinanceGateway(
  config: SupabaseSubscriptionFinanceConfig,
): SubscriptionFinanceGateway {
  const userClient = createClient(config.supabaseUrl, config.anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      headers: config.authorization
        ? { Authorization: config.authorization }
        : {},
    },
  });
  const serviceClient = createClient(
    config.supabaseUrl,
    config.serviceRoleKey,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  function attemptFromRow(
    row: Record<string, unknown>,
  ): SubscriptionAttemptRequest {
    return {
      paymentAttemptId: String(row.id ?? row.payment_attempt_id ?? ""),
      subscriptionCycleId: String(
        row.subscription_cycle_id ?? row.subscriptionCycleId ?? "",
      ),
      obligationId: String(row.obligation_id ?? ""),
      amount: Number(row.amount),
      currency: String(row.currency) as "KES",
      status: String(row.status ?? row.attempt_status ?? ""),
      checkoutRequestId: row.provider_request_ref
        ? String(row.provider_request_ref)
        : row.checkout_request_id
        ? String(row.checkout_request_id)
        : null,
    };
  }

  return {
    async requestAnnualSubscriptionMpesaAttempt(
      subscriptionCycleId,
      phone,
      idempotencyKey,
    ) {
      const { data, error } = await userClient
        .schema("finance")
        .rpc("request_annual_subscription_mpesa_attempt", {
          p_subscription_cycle_id: subscriptionCycleId,
          p_phone: phone,
          p_idempotency_key: idempotencyKey,
        });
      if (error) throw new Error(error.message);
      const row = asRow(data);
      if (!row) throw new Error("subscription_attempt_missing");
      return attemptFromRow(row);
    },

    async getAttemptState(paymentAttemptId) {
      const { data, error } = await serviceClient
        .schema("finance")
        .from("payment_attempts")
        .select(
          "id, obligation_id, provider_request_ref, amount, currency, status",
        )
        .eq("id", paymentAttemptId)
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (!data) throw new Error("subscription_attempt_missing");
      return attemptFromRow(data as Record<string, unknown>);
    },

    async claimAttempt(paymentAttemptId) {
      const { data, error } = await userClient
        .schema("finance")
        .rpc("claim_mpesa_attempt_safe", {
          p_payment_attempt_id: paymentAttemptId,
        });
      if (error) throw new Error(error.message);
      const row = asRow(data);
      if (!row || row.attempt_status !== "processing") {
        throw new Error("payment_attempt_not_claimable");
      }
      return { status: "processing" };
    },

    async completeInitiation(
      paymentAttemptId,
      checkoutRequestId,
      failureCode = null,
      failureMessage = null,
    ) {
      const { error } = await serviceClient
        .schema("finance")
        .rpc("complete_mpesa_initiation", {
          p_payment_attempt_id: paymentAttemptId,
          p_checkout_request_id: checkoutRequestId,
          p_failure_code: failureCode,
          p_failure_message: failureMessage,
        });
      if (error) throw new Error(error.message);
    },

    async recordVerificationEvidence(evidence: FinanceVerificationEvidence) {
      const { data, error } = await serviceClient
        .schema("finance")
        .rpc("record_mpesa_verification_evidence", {
          p_payment_attempt_id: evidence.paymentAttemptId,
          p_provider_event_id: evidence.providerEventId,
          p_verified_provider_reference: evidence.providerReference,
          p_verified_amount: evidence.verifiedAmount,
          p_verified_currency: evidence.verifiedCurrency,
          p_callback_payload: evidence.callbackPayload,
          p_provider_query_result: evidence.providerQueryResult,
          p_provider_verified_at: evidence.providerVerifiedAt,
        });
      if (error) throw new Error(error.message);
      if (typeof data !== "string" || !data) {
        throw new Error("finance_evidence_id_missing");
      }
      return data;
    },

    async confirmPayment(paymentAttemptId, providerEventId) {
      const { data, error } = await serviceClient
        .schema("finance")
        .rpc("confirm_annual_subscription_payment", {
          p_payment_attempt_id: paymentAttemptId,
          p_provider_event_id: providerEventId,
        });
      if (error) throw new Error(error.message);
      const row = asRow(data);
      if (!row || typeof row.payment_id !== "string" || !row.payment_id) {
        throw new Error("finance_payment_id_missing");
      }
      return row.payment_id;
    },

    async loadAttemptByCheckoutRequestId(
      checkoutRequestId,
    ): Promise<MpesaPaymentAttempt | null> {
      const { data, error } = await serviceClient
        .schema("finance")
        .from("payment_attempts")
        .select("id, provider_request_ref, amount, currency, metadata")
        .eq("provider", "mpesa")
        .eq("provider_request_ref", checkoutRequestId)
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (!data) return null;
      const row = data as Record<string, unknown>;
      const metadata = (row.metadata ?? {}) as Record<string, unknown>;
      return {
        paymentAttemptId: String(row.id),
        checkoutRequestId: String(row.provider_request_ref),
        phone: String(metadata.phone ?? ""),
        amount: Number(row.amount),
        currency: String(row.currency) as "KES",
      };
    },

    async recordDefinitiveFailure(input) {
      const { data, error } = await serviceClient
        .schema("finance")
        .rpc("record_mpesa_definitive_failure", {
          p_payment_attempt_id: input.paymentAttemptId,
          p_provider_event_id: input.providerEventId,
          p_checkout_request_id: input.checkoutRequestId,
          p_failure_code: input.failureCode,
          p_failure_description: input.failureDescription,
          p_callback_payload: input.callbackPayload,
          p_provider_query_result: input.providerQueryResult,
          p_callback_authentication_succeeded: true,
          p_provider_verified_at: input.providerVerifiedAt,
        });
      if (error) throw new Error(error.message);
      if (typeof data !== "string" || !data) {
        throw new Error("finance_failure_event_id_missing");
      }
      return data;
    },
  };
}
