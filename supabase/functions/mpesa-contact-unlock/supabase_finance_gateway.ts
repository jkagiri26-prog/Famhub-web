import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { FinanceGateway } from "./orchestrator.ts";
import type {
  FinanceVerificationEvidence,
  MpesaPaymentAttempt,
} from "./contract.ts";

export type SupabaseFinanceGatewayConfig = {
  supabaseUrl: string;
  anonKey: string;
  serviceRoleKey: string;
  authorization: string | null;
};

/**
 * Server-side Finance boundary.
 *
 * The caller JWT is used only for claim_mpesa_attempt_safe. Initiation
 * completion, evidence recording, and contact-unlock confirmation use the
 * service-role client and are never exposed to Flutter.
 */
export function createSupabaseFinanceGateway(
  config: SupabaseFinanceGatewayConfig,
): FinanceGateway {
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

  return {
    async claimAttempt(paymentAttemptId) {
      const { data, error } = await userClient
        .schema("finance")
        .rpc("claim_mpesa_attempt_safe", {
          p_payment_attempt_id: paymentAttemptId,
        });
      if (error) throw new Error(error.message);
      const row = Array.isArray(data) ? data[0] : data;
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
        .schema("marketplace")
        .rpc("confirm_contact_unlock_payment", {
          p_payment_attempt_id: paymentAttemptId,
          p_provider_event_id: providerEventId,
        });
      if (error) throw new Error(error.message);
      if (typeof data !== "string" || !data) {
        throw new Error("finance_payment_id_missing");
      }
      return data;
    },

    async loadAttemptByCheckoutRequestId(
      checkoutRequestId: string,
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
      const metadata = (data.metadata ?? {}) as Record<string, unknown>;
      return {
        paymentAttemptId: String(data.id),
        checkoutRequestId: String(data.provider_request_ref),
        phone: String(metadata.phone ?? ""),
        amount: Number(data.amount),
        currency: String(data.currency) as "KES",
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
