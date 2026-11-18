import type {
  MpesaProvider,
  MpesaStkPushRequest,
  MpesaStkPushResponse,
  MpesaStkQueryResult,
} from "./contract.ts";

export class MockMpesaProvider implements MpesaProvider {
  initiation: MpesaStkPushResponse = {
    merchantRequestId: "merchant-1",
    checkoutRequestId: "checkout-1",
    responseCode: "0",
    responseDescription: "Success",
    customerMessage: "Check your phone",
  };
  query: MpesaStkQueryResult = {
    checkoutRequestId: "checkout-1",
    resultCode: "0",
    resultDesc: "Success",
    receiptNumber: "RCPT-1",
    amount: 150,
    currency: "KES",
  };
  initiationError?: Error;
  queryError?: Error;
  initiationCalls: MpesaStkPushRequest[] = [];
  queryCalls: string[] = [];

  async initiateStkPush(
    request: MpesaStkPushRequest,
  ): Promise<MpesaStkPushResponse> {
    this.initiationCalls.push(request);
    if (this.initiationError) throw this.initiationError;
    return this.initiation;
  }

  async queryStkPush(checkoutRequestId: string): Promise<MpesaStkQueryResult> {
    this.queryCalls.push(checkoutRequestId);
    if (this.queryError) throw this.queryError;
    return { ...this.query, checkoutRequestId };
  }
}
