// ============================================================================
// Reputation Processing Worker — trusted execution boundary.
//
// Required server-side secrets:
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   REPUTATION_WORKER_SECRET
//
// Optional non-secret:
//   REPUTATION_WORKER_ID
//
// The worker calls only the approved system.* RPC gateways.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  handleWorkerRequest,
  type WorkerConfig,
  type WorkerRpc,
  type WorkerRpcResult,
} from "./handler.ts";

function createReputationWorkerRpc(config: WorkerConfig): WorkerRpc {
  const supabase = createClient(config.supabaseUrl, config.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  return {
    async claim(
      limit: number,
      workerId: string,
      leaseSeconds: number,
    ): Promise<WorkerRpcResult> {
      const { data, error } = await supabase
        .schema("system")
        .rpc("claim_reputation_processing_work", {
          p_limit: limit,
          p_worker_id: workerId,
          p_lease_seconds: leaseSeconds,
        });
      return { data, error };
    },

    async ingest(orderId: string): Promise<WorkerRpcResult> {
      const { data, error } = await supabase
        .schema("system")
        .rpc("ingest_reputation_stock_order_engagement", {
          p_order_id: orderId,
        });
      return { data, error };
    },

    async captureEvidence(
      engagementId: string,
      requestId: string,
    ): Promise<WorkerRpcResult> {
      const { data, error } = await supabase
        .schema("system")
        .rpc("capture_reputation_order_evidence", {
          p_engagement_id: engagementId,
          p_capture_actor_profile_id: null,
          p_request_id: requestId,
        });
      return { data, error };
    },

    async complete(
      workId: string,
      claimToken: string,
      outcome: string,
      errorCategory: string | null,
      errorCode: string | null,
      errorMessage: string | null,
      runId: string,
    ): Promise<WorkerRpcResult> {
      const { data, error } = await supabase
        .schema("system")
        .rpc("complete_reputation_processing_work", {
          p_work_id: workId,
          p_claim_token: claimToken,
          p_outcome: outcome,
          p_error_category: errorCategory,
          p_error_code: errorCode,
          p_error_message: errorMessage,
          p_run_id: runId,
        });
      return { data, error };
    },
  };
}

Deno.serve((req: Request) =>
  handleWorkerRequest(req, Deno.env, createReputationWorkerRpc)
);
