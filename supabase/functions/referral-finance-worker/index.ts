// ============================================================================
// Refer & Earn Finance Event Worker — SERVER-SIDE ONLY
// ----------------------------------------------------------------------------
// Thin orchestration boundary. Qualification and Finance accounting remain in
// the existing referrals consumer and Finance functions.
//
// Required server-side secrets:
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   REFERRAL_WORKER_SECRET
//
// Do not expose any of these values to clients.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleWorkerRequest } from "./handler.ts";

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  return handleWorkerRequest(req, Deno.env, async (limit) => {
    if (!supabaseUrl || !serviceRoleKey) {
      return { data: null, error: { code: "server_configuration_missing" } };
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await supabase
      .schema("system")
      .rpc("process_referral_finance_events", { p_limit: limit });

    return {
      data,
      error: error ? { code: error.code ?? null } : null,
    };
  });
});
