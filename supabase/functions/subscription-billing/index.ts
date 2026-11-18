// ============================================================================
// Subscription billing M-Pesa boundary — SERVER-SIDE ONLY
// ----------------------------------------------------------------------------
// The client can start a subscription payment attempt, but can never invoke
// Finance finalization or subscription activation. Provider callbacks use the
// existing fail-closed Daraja callback boundary.
// ============================================================================

import {
  type MpesaProvider,
  UnconfiguredMpesaProvider,
} from "../mpesa-contact-unlock/contract.ts";
import { loadDarajaConfig } from "../mpesa-contact-unlock/daraja_config.ts";
import { DarajaProvider } from "../mpesa-contact-unlock/daraja_provider.ts";
import { handleDarajaCallback } from "../mpesa-contact-unlock/daraja_callback.ts";
import { createDarajaCallbackAuthenticator } from "../mpesa-contact-unlock/daraja_callback_auth.ts";
import { handleSubscriptionBillingRequest } from "./handler.ts";
import { createSubscriptionFinanceGateway } from "./finance_gateway.ts";

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

  const finance = createSubscriptionFinanceGateway({
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

  return handleSubscriptionBillingRequest(req, {
    provider,
    finance,
    callbackUrl: daraja.status === "configured"
      ? daraja.config.callbackUrl
      : "",
  });
});
