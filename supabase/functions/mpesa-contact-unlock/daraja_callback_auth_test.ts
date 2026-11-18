import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createDarajaCallbackAuthenticator } from "./daraja_callback_auth.ts";
import {
  MpesaCallbackAuthConfigurationError,
  MpesaCallbackAuthenticationError,
} from "./mpesa_callback_auth.ts";

Deno.test("no callback authentication mode is a configuration error", () => {
  assertThrows(
    () => createDarajaCallbackAuthenticator(undefined),
    MpesaCallbackAuthConfigurationError,
    "callback_auth_mode_missing",
  );
  assertThrows(
    () => createDarajaCallbackAuthenticator(""),
    MpesaCallbackAuthConfigurationError,
    "callback_auth_mode_missing",
  );
});

Deno.test("unknown callback authentication mode is rejected", () => {
  assertThrows(
    () => createDarajaCallbackAuthenticator("callback_secret"),
    MpesaCallbackAuthConfigurationError,
    "callback_auth_mode_unsupported",
  );
});

Deno.test("supported disabled adapter is selected and rejects all callbacks", async () => {
  const authenticator = createDarajaCallbackAuthenticator("disabled");
  assertEquals(authenticator.mode, "disabled");
  await assertRejects(
    () => authenticator.authenticate(new Request("http://localhost")),
    MpesaCallbackAuthenticationError,
    "callback_authentication_disabled",
  );
});

Deno.test("callback authentication errors do not expose secrets", () => {
  const error = new MpesaCallbackAuthenticationError(
    "callback_authentication_disabled",
  );
  assertEquals(error.message.includes("fixture"), false);
  assertEquals(error.message.includes("token"), false);
});
