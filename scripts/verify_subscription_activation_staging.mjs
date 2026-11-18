#!/usr/bin/env node
import crypto from 'node:crypto';

const PRODUCTION_REF = 'erbxiqdfjmqnoeyjupru';
const EXPECTED_STAGING_REF = 'ivcddanirifujxtexmzh';
const url = process.env.STAGING_SUPABASE_URL?.replace(/\/+$/, '');
const anonKey = process.env.STAGING_SUPABASE_ANON_KEY;
const serviceKey = process.env.STAGING_SUPABASE_SERVICE_ROLE_KEY;

const checks = [];
const failures = [];

function record(name, ok, detail = '') {
  checks.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${!ok && detail ? ` — ${detail}` : ''}`);
  if (!ok) failures.push({ name, detail });
}
function abort(message) {
  console.error(`ABORT: ${message}`);
  process.exit(2);
}
if (!url || !anonKey || !serviceKey) abort('STAGING_SUPABASE_URL, STAGING_SUPABASE_ANON_KEY and STAGING_SUPABASE_SERVICE_ROLE_KEY are required.');
if (process.env.ALLOW_STAGING_RPC_VERIFICATION !== 'YES') abort('ALLOW_STAGING_RPC_VERIFICATION must be YES.');
const ref = new URL(url).hostname.split('.')[0];
if (ref === PRODUCTION_REF) abort('Refusing to run against production.');
if (ref !== EXPECTED_STAGING_REF) abort(`Refusing unexpected project ref: ${ref}`);

const serviceHeaders = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' };
const userHeaders = (token) => ({ apikey: anonKey, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' });
function parseBody(text, contentType) {
  if (!text) return null;
  if ((contentType || '').includes('application/json')) {
    try { return JSON.parse(text); } catch { return text; }
  }
  return text;
}
async function request(path, options = {}) {
  const response = await fetch(`${url}${path}`, options);
  const text = await response.text();
  return { status: response.status, ok: response.ok, body: parseBody(text, response.headers.get('content-type')) };
}
function headersFor(token, schema, extra = {}) {
  return {
    apikey: token === serviceKey ? serviceKey : anonKey,
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    ...(schema ? { 'Content-Profile': schema, 'Accept-Profile': schema } : {}),
    ...extra,
  };
}
async function rpc(schema, fn, body, token = serviceKey) {
  return request(`/rest/v1/rpc/${fn}`, { method: 'POST', headers: headersFor(token, schema), body: JSON.stringify(body ?? {}) });
}
async function insertRow(schema, table, row, token = serviceKey) {
  return request(`/rest/v1/${table}`, { method: 'POST', headers: headersFor(token, schema, { Prefer: 'return=representation' }), body: JSON.stringify(row) });
}
async function selectRows(schema, table, query, token = serviceKey) {
  return request(`/rest/v1/${table}?${query}`, { method: 'GET', headers: headersFor(token, schema) });
}
function firstRow(body, name) {
  if (Array.isArray(body) && body.length > 0) return body[0];
  if (body && typeof body === 'object' && !Array.isArray(body)) return body;
  throw new Error(`${name}: expected a row, received ${JSON.stringify(body)}`);
}
function scalar(body) {
  return Array.isArray(body) ? body[0] : body;
}
function denied(name, response) {
  record(name, !response.ok, response.ok ? `unexpectedly succeeded: ${JSON.stringify(response.body)}` : `denied HTTP ${response.status}`);
}
function nairobiBoundary(dateStr, addDays = 0) {
  const d = new Date(`${dateStr}T00:00:00+03:00`);
  d.setUTCDate(d.getUTCDate() + addDays);
  return d.toISOString();
}

const suffix = `${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
const email = process.env.STAGING_TEST_EMAIL || `activation-verify+${suffix}@example.com`;
const password = process.env.STAGING_TEST_PASSWORD || `ActVerify-${crypto.randomBytes(18).toString('base64url')}`;
let userToken = '';
let profileId = '';
let billingId = '';
let billingEntityId = '';
let planId = '';
let platformEntityId = '00000000-0000-4000-8000-000000000104';

async function purchase(label) {
  const r = await rpc('finance', 'create_annual_subscription', {
    p_billing_account_id: billingId,
    p_plan_id: planId,
    p_invoice_number: `STG-ACT-${suffix}-${label}`,
    p_idempotency_key: `stg-act-${suffix}-${label}`,
    p_requested_start_date: null,
    p_due_at: null,
  }, serviceKey);
  if (!r.ok) throw new Error(`purchase ${label} failed: ${r.status} ${JSON.stringify(r.body)}`);
  return firstRow(r.body, `purchase ${label}`);
}

async function makeAttempt(cycle, amount, label, { fail = false } = {}) {
  const checkout = `CHECKOUT-${suffix}-${label}`;
  const receipt = `RECEIPT-${suffix}-${label}`;
  const eventKey = `EVENT-${suffix}-${label}`;
  const attemptResult = await rpc('finance', 'create_payment_attempt', {
    p_obligation_id: cycle.obligation_id,
    p_provider: 'mpesa',
    p_method_type: 'mpesa',
    p_amount: amount,
    p_idempotency_key: `attempt-${suffix}-${label}`,
    p_payment_method_id: null,
    p_metadata: { phone: '254700000000', finance_charge_code: 'subscription' },
  }, serviceKey);
  if (!attemptResult.ok) throw new Error(`create_payment_attempt ${label}: ${attemptResult.status} ${JSON.stringify(attemptResult.body)}`);
  const attemptId = scalar(attemptResult.body);
  const claimResult = await rpc('finance', 'claim_mpesa_attempt_safe', { p_payment_attempt_id: attemptId }, userToken);
  if (!claimResult.ok) throw new Error(`claim_mpesa_attempt_safe ${label}: ${claimResult.status} ${JSON.stringify(claimResult.body)}`);
  const initiation = await rpc('finance', 'complete_mpesa_initiation', {
    p_payment_attempt_id: attemptId,
    p_checkout_request_id: checkout,
    p_failure_code: null,
    p_failure_message: null,
  }, serviceKey);
  if (!initiation.ok) throw new Error(`complete_mpesa_initiation ${label}: ${initiation.status} ${JSON.stringify(initiation.body)}`);
  if (fail) {
    const callback = { Body: { stkCallback: { ResultCode: 1032, ResultDesc: 'Request cancelled by user', CheckoutRequestID: checkout, CallbackMetadata: { Item: [] } } } };
    const query = { ResponseCode: '0', ResultCode: '1032', ResultDesc: 'Request cancelled by user', CheckoutRequestID: checkout };
    const failure = await rpc('finance', 'record_mpesa_definitive_failure', {
      p_payment_attempt_id: attemptId,
      p_provider_event_id: eventKey,
      p_checkout_request_id: checkout,
      p_failure_code: '1032',
      p_failure_description: 'Request cancelled by user',
      p_callback_payload: callback,
      p_provider_query_result: query,
      p_callback_authentication_succeeded: true,
      p_provider_verified_at: new Date().toISOString(),
    }, serviceKey);
    if (!failure.ok) throw new Error(`record_mpesa_definitive_failure ${label}: ${failure.status} ${JSON.stringify(failure.body)}`);
    return { attemptId, checkout, receipt, eventKey, failed: true };
  }
  const callback = { Body: { stkCallback: { ResultCode: 0, ResultDesc: 'Success', CheckoutRequestID: checkout, CallbackMetadata: { Item: [ { Name: 'MpesaReceiptNumber', Value: receipt }, { Name: 'Amount', Value: amount } ] } } } };
  const query = { ResponseCode: '0', ResultCode: '0', ResultDesc: 'Success', CheckoutRequestID: checkout };
  const evidence = await rpc('finance', 'record_mpesa_verification_evidence', {
    p_payment_attempt_id: attemptId,
    p_provider_event_id: eventKey,
    p_verified_provider_reference: receipt,
    p_verified_amount: amount,
    p_verified_currency: 'KES',
    p_callback_payload: callback,
    p_provider_query_result: query,
    p_provider_verified_at: new Date().toISOString(),
  }, serviceKey);
  if (!evidence.ok) throw new Error(`record_mpesa_verification_evidence ${label}: ${evidence.status} ${JSON.stringify(evidence.body)}`);
  const eventId = scalar(evidence.body);
  const finalize = await rpc('finance', 'finalize_mpesa_payment', {
    p_payment_attempt_id: attemptId,
    p_provider_event_id: eventId,
  }, serviceKey);
  if (!finalize.ok) throw new Error(`finalize_mpesa_payment ${label}: ${finalize.status} ${JSON.stringify(finalize.body)}`);
  return { attemptId, checkout, receipt, eventId, paymentId: scalar(finalize.body), failed: false };
}

try {
  const createUser = await request('/auth/v1/admin/users', {
    method: 'POST', headers: serviceHeaders,
    body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { purpose: 'activation-verification' } }),
  });
  if (!createUser.ok) throw new Error(`auth admin create user: ${createUser.status} ${JSON.stringify(createUser.body)}`);
  const signIn = await request('/auth/v1/token?grant_type=password', {
    method: 'POST', headers: { apikey: anonKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!signIn.ok || !signIn.body?.access_token) throw new Error(`sign-in: ${signIn.status} ${JSON.stringify(signIn.body)}`);
  userToken = signIn.body.access_token;
  const country = await insertRow('core', 'countries', { name: `Activation Verifyland ${suffix}`, iso_alpha2: 'ZZ', iso_alpha3: 'ZZZ', dialing_code: '999', is_active: true });
  if (!country.ok) throw new Error(`country: ${country.status} ${JSON.stringify(country.body)}`);
  const countryId = firstRow(country.body, 'country').id;
  const profile = await insertRow('users', 'profiles', { auth_user_id: createUser.body.id, first_name: 'Activation', last_name: 'Verify', email, country_id: countryId, is_active: true, account_status: 'active' });
  if (!profile.ok) throw new Error(`profile: ${profile.status} ${JSON.stringify(profile.body)}`);
  profileId = firstRow(profile.body, 'profile').id;
  const billing = await rpc('system', 'ensure_individual_billing_account', {}, userToken);
  if (!billing.ok) throw new Error(`ensure billing: ${billing.status} ${JSON.stringify(billing.body)}`);
  const b = firstRow(billing.body, 'billing');
  billingId = b.billing_account_id;
  billingEntityId = b.entity_id;
  const plan = await rpc('system', 'create_annual_subscription_plan', { p_plan_key: `activation-plan-${suffix}`, p_plan_name: `Activation Plan ${suffix}`, p_amount: 12000, p_module_key: null, p_features_json: {} }, serviceKey);
  if (!plan.ok) throw new Error(`plan: ${plan.status} ${JSON.stringify(plan.body)}`);
  planId = firstRow(plan.body, 'plan').plan_id;

  // Referral account setup and idempotency.
  const ref1 = await rpc('finance', 'ensure_referral_accounts', { p_platform_entity_id: platformEntityId, p_payable_account_code: '2400', p_payable_account_name: 'Staging Referral Rewards Payable' }, serviceKey);
  const ref1row = ref1.ok ? firstRow(ref1.body, 'referral accounts') : null;
  record('ensure_referral_accounts succeeds', ref1.ok && ref1row?.expense_account_code === '5200' && ref1row?.payable_account_code === '2400' && ref1row?.currency === 'KES', JSON.stringify(ref1.body));
  const ref2 = await rpc('finance', 'ensure_referral_accounts', { p_platform_entity_id: platformEntityId, p_payable_account_code: '2400', p_payable_account_name: 'Staging Referral Rewards Payable' }, serviceKey);
  const ref2row = ref2.ok ? firstRow(ref2.body, 'referral accounts retry') : null;
  record('ensure_referral_accounts is idempotent', ref1.ok && ref2.ok && ref1row.expense_account_id === ref2row.expense_account_id && ref1row.payable_account_id === ref2row.payable_account_id, JSON.stringify(ref2.body));
  const refDenied = await rpc('finance', 'ensure_referral_accounts', { p_platform_entity_id: platformEntityId, p_payable_account_code: '2401', p_payable_account_name: 'Unauthorized' }, userToken);
  denied('authenticated cannot call ensure_referral_accounts', refDenied);

  const successCycle = await purchase('success');
  const missingCycle = await purchase('missing');
  const partialCycle = await purchase('partial');
  const failedCycle = await purchase('failed');
  const concurrentCycle = await purchase('concurrent');

  // Missing payment evidence.
  const missing = await rpc('finance', 'complete_annual_subscription', { p_subscription_cycle_id: missingCycle.subscription_cycle_id, p_obligation_id: missingCycle.obligation_id }, serviceKey);
  record('missing payment evidence is rejected', !missing.ok, `${missing.status} ${JSON.stringify(missing.body)}`);

  // Partial settlement.
  const partialPayment = await makeAttempt(partialCycle, 5000, 'partial');
  const partial = await rpc('finance', 'complete_annual_subscription', { p_subscription_cycle_id: partialCycle.subscription_cycle_id, p_obligation_id: partialCycle.obligation_id }, serviceKey);
  record('partial settlement is rejected', !partial.ok, `${partial.status} ${JSON.stringify(partial.body)}`);
  const partialObligation = await selectRows('finance', 'obligations', `id=eq.${partialCycle.obligation_id}&select=status,amount,currency`, serviceKey);
  record('partial settlement leaves obligation partially settled', partialObligation.ok && partialObligation.body[0]?.status === 'partially_settled', JSON.stringify(partialObligation.body));

  // Failed payment attempt.
  const failedAttempt = await makeAttempt(failedCycle, 12000, 'failed', { fail: true });
  const failed = await rpc('finance', 'complete_annual_subscription', { p_subscription_cycle_id: failedCycle.subscription_cycle_id, p_obligation_id: failedCycle.obligation_id }, serviceKey);
  record('failed payment attempt activation is rejected', !failed.ok, `${failed.status} ${JSON.stringify(failed.body)}`);

  // Successful settlement and activation.
  const successPayment = await makeAttempt(successCycle, 12000, 'success');
  const journalsBefore = await selectRows('finance', 'journals', 'select=id', serviceKey);
  const success = await rpc('finance', 'complete_annual_subscription', { p_subscription_cycle_id: successCycle.subscription_cycle_id, p_obligation_id: successCycle.obligation_id }, serviceKey);
  const activated = success.ok ? firstRow(success.body, 'activation') : null;
  record('full settlement activates subscription', success.ok && activated?.status === 'active', `${success.status} ${JSON.stringify(success.body)}`);
  const journalsAfter = await selectRows('finance', 'journals', 'select=id', serviceKey);
  record('activation does not create a journal', journalsBefore.ok && journalsAfter.ok && journalsBefore.body.length === journalsAfter.body.length, `before=${journalsBefore.body?.length} after=${journalsAfter.body?.length}`);

  const active = await selectRows('system', 'active_subscriptions', `id=eq.${activated?.active_subscription_id}&select=id,status,billing_account_id,plan_id,start_date,end_date`, serviceKey);
  record('active subscription is active and linked', active.ok && active.body[0]?.status === 'active' && active.body[0]?.billing_account_id === billingId && active.body[0]?.plan_id === planId, JSON.stringify(active.body));
  const expectedStart = nairobiBoundary(successCycle.period_start);
  const expectedEnd = nairobiBoundary(successCycle.period_end, 1);
  const actualStart = active.body?.[0]?.start_date ? new Date(active.body[0].start_date).toISOString() : null;
  const actualEnd = active.body?.[0]?.end_date ? new Date(active.body[0].end_date).toISOString() : null;
  record('active start_date uses Africa/Nairobi midnight', active.ok && actualStart === expectedStart, `expected=${expectedStart} actual=${actualStart}`);
  record('active end_date is exclusive next Africa/Nairobi midnight', active.ok && actualEnd === expectedEnd, `expected=${expectedEnd} actual=${actualEnd}`);

  const invoice = await selectRows('system', 'invoices', `id=eq.${successCycle.invoice_id}&select=id,status,total_amount,currency`, serviceKey);
  record('invoice becomes paid', invoice.ok && invoice.body[0]?.status === 'paid' && invoice.body[0]?.total_amount === 12000 && invoice.body[0]?.currency === 'KES', JSON.stringify(invoice.body));
  const obligation = await selectRows('finance', 'obligations', `id=eq.${successCycle.obligation_id}&select=id,status,amount,currency`, serviceKey);
  record('obligation is fully settled', obligation.ok && obligation.body[0]?.status === 'settled' && obligation.body[0]?.amount === 12000 && obligation.body[0]?.currency === 'KES', JSON.stringify(obligation.body));

  const activationIds = activated ? [activated.event_id, activated.settlement_id, activated.payment_id] : [];
  record('activation returns one event and settlement', success.ok && activationIds.every(Boolean), JSON.stringify(activated));

  const retry = await rpc('finance', 'complete_annual_subscription', { p_subscription_cycle_id: successCycle.subscription_cycle_id, p_obligation_id: successCycle.obligation_id }, serviceKey);
  const retryRow = retry.ok ? firstRow(retry.body, 'activation retry') : null;
  record('repeated activation is idempotent', retry.ok && retryRow.event_id === activated.event_id && retryRow.settlement_id === activated.settlement_id && retryRow.payment_id === activated.payment_id, `${retry.status} ${JSON.stringify(retry.body)}`);

  // Referral account relationship: ensure remains idempotent after activation.
  const refAfter = await rpc('finance', 'ensure_referral_accounts', { p_platform_entity_id: platformEntityId, p_payable_account_code: '2400', p_payable_account_name: 'Staging Referral Rewards Payable' }, serviceKey);
  const refAfterRow = refAfter.ok ? firstRow(refAfter.body, 'referral accounts after activation') : null;
  record('activation does not create duplicate referral accounts', ref1.ok && refAfter.ok && ref1row.expense_account_id === refAfterRow.expense_account_id && ref1row.payable_account_id === refAfterRow.payable_account_id, JSON.stringify(refAfter.body));

  // Concurrency: settle a separate cycle, then activate concurrently.
  const concurrentPayment = await makeAttempt(concurrentCycle, 12000, 'concurrent');
  const concurrentResults = await Promise.all([
    rpc('finance', 'complete_annual_subscription', { p_subscription_cycle_id: concurrentCycle.subscription_cycle_id, p_obligation_id: concurrentCycle.obligation_id }, serviceKey),
    rpc('finance', 'complete_annual_subscription', { p_subscription_cycle_id: concurrentCycle.subscription_cycle_id, p_obligation_id: concurrentCycle.obligation_id }, serviceKey),
  ]);
  const concurrentRows = concurrentResults.filter((r) => r.ok).map((r) => firstRow(r.body, 'concurrent activation'));
  const concurrentEventIds = [...new Set(concurrentRows.map((r) => r.event_id))];
  record('concurrent activation has one winning event', concurrentRows.length >= 1 && concurrentEventIds.length === 1, JSON.stringify(concurrentResults.map((r) => ({ ok: r.ok, status: r.status, event_id: r.body?.event_id }))));
  record('concurrent activation creates no duplicate event', concurrentRows.every((r) => r.event_id === concurrentRows[0].event_id), JSON.stringify(concurrentRows));
  const concurrentActive = await selectRows('system', 'active_subscriptions', `id=eq.${concurrentCycle.active_subscription_id}&select=id,status`, serviceKey);
  const concurrentInvoice = await selectRows('system', 'invoices', `id=eq.${concurrentCycle.invoice_id}&select=id,status`, serviceKey);
  record('concurrent activation leaves one active subscription and paid invoice', concurrentActive.ok && concurrentActive.body[0]?.status === 'active' && concurrentInvoice.ok && concurrentInvoice.body[0]?.status === 'paid', `active=${JSON.stringify(concurrentActive.body)} invoice=${JSON.stringify(concurrentInvoice.body)}`);

} catch (error) {
  record('verification execution', false, String(error?.stack || error));
}
console.log('\nVerification summary');
for (const c of checks) console.log(`${c.ok ? 'PASS' : 'FAIL'}  ${c.name}`);
if (failures.length > 0) {
  console.error(`\n${failures.length} check(s) failed.`);
  process.exit(1);
}
console.log(`\nAll ${checks.length} checks passed.`);
