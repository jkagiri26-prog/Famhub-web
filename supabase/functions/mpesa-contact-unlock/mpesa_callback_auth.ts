export type MpesaAuthenticatedCallback = {
  checkoutRequestId: string;
  resultCode: string;
  resultDesc: string;
  receiptNumber?: string;
  amount?: number;
  callbackPayload: Record<string, unknown>;
};

export interface MpesaCallbackAuthenticator {
  readonly mode: string;
  authenticate(request: Request): Promise<MpesaAuthenticatedCallback>;
}

export class MpesaCallbackAuthConfigurationError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "MpesaCallbackAuthConfigurationError";
  }
}

export class MpesaCallbackAuthenticationError extends Error {
  constructor(readonly code = "callback_not_authenticated") {
    super(code);
    this.name = "MpesaCallbackAuthenticationError";
  }
}

export class MpesaCallbackPayloadError extends Error {
  constructor(readonly code = "invalid_callback_payload") {
    super(code);
    this.name = "MpesaCallbackPayloadError";
  }
}
