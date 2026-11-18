import {
  type MpesaAuthenticatedCallback,
  MpesaCallbackAuthConfigurationError,
  MpesaCallbackAuthenticationError,
  type MpesaCallbackAuthenticator,
} from "./mpesa_callback_auth.ts";

/**
 * Only modes that are explicitly implemented are accepted. There is currently
 * no approved Safaricom callback-authentication protocol in this repository,
 * so "disabled" is the only supported mode and it rejects every callback.
 */
const SUPPORTED_MODES = ["disabled"] as const;
type SupportedMode = (typeof SUPPORTED_MODES)[number];

class DisabledDarajaCallbackAuthenticator
  implements MpesaCallbackAuthenticator {
  readonly mode: SupportedMode = "disabled";

  authenticate(): Promise<MpesaAuthenticatedCallback> {
    return Promise.reject(
      new MpesaCallbackAuthenticationError("callback_authentication_disabled"),
    );
  }
}

export function createDarajaCallbackAuthenticator(
  mode: string | undefined,
): MpesaCallbackAuthenticator {
  const normalized = (mode ?? "").trim();
  if (!normalized) {
    throw new MpesaCallbackAuthConfigurationError(
      "callback_auth_mode_missing",
    );
  }
  if (normalized === "disabled") {
    return new DisabledDarajaCallbackAuthenticator();
  }
  throw new MpesaCallbackAuthConfigurationError(
    "callback_auth_mode_unsupported",
  );
}
