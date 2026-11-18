// ============================================================================
// Contact-unlock M-Pesa initiation boundary — SERVER-SIDE ONLY
// ----------------------------------------------------------------------------
// The generic Daraja adapter is activated only when its complete server-side
// configuration is present. Otherwise initiation returns 503. No credentials
// or provider endpoints are committed to this repository.
//
// Required server-side configuration for the Finance gateway:
//   SUPABASE_URL
//   SUPABASE_ANON_KEY
//   SUPABASE_SERVICE_ROLE_KEY
//
// Provider credentials, endpoints, callback URLs, and callback authentication
// come only from server-side environment variables. Callback authentication is
// disabled until an approved mechanism is explicitly configured.
// ============================================================================

import { type MpesaProvider, UnconfiguredMpesaProvider } from "./contract.ts";
import { loadDarajaConfig } from "./daraja_config.ts";
import { DarajaProvider } from "./daraja_provider.ts";
import { handleContactUnlockRequest } from "./handler.ts";
import { handleDarajaCallback } from "./daraja_callback.ts";
import { createDarajaCallbackAuthenticator } from "./daraja_callback_auth.ts";
import { createSupabaseFinanceGateway } from "./supabase_finance_gateway.ts";

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const daraja = loadDarajaConfig((key) => Deno.env.get(key));

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return new Response(
      JSON.stringify({ ok: false, error: "server_configuration_missing" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const finance = createSupabaseFinanceGateway({
    supabaseUrl,
    anonKey,
    serviceRoleKey,
    authorization: req.headers.get("authorization"),
  });

  const provider: MpesaProvider = daraja.status === "configured"
    ? new DarajaProvider(daraja.config)
    : new UnconfiguredMpesaProvider();

  const url = new URL(req.url);
  if (url.pathname.endsWith("/callback")) {
    try {
      const authenticate = createDarajaCallbackAuthenticator(
        Deno.env.get("DARAJA_CALLBACK_AUTH_MODE"),
      );
      return handleDarajaCallback(req, { provider, finance, authenticate });
    } catch (_) {
      return new Response(
        JSON.stringify({ ok: false, error: "callback_auth_not_configured" }),
        { status: 503, headers: { "Content-Type": "application/json" } },
      );
    }
  }

  return handleContactUnlockRequest(req, {
    provider,
    finance,
    callbackUrl: daraja.status === "configured"
      ? daraja.config.callbackUrl
      : "",
  });
});
