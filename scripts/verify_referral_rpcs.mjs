#!/usr/bin/env node
/**
 * Disposable-environment RPC verification for Refer & Earn.
 *
 * NEVER run against production. The script refuses the known production
 * project ref and requires an explicit staging confirmation flag.
 *
 * Required environment:
 *   STAGING_SUPABASE_URL
 *   STAGING_SUPABASE_ANON_KEY
 *   STAGING_SUPABASE_SERVICE_ROLE_KEY
 *   ALLOW_STAGING_RPC_VERIFICATION=YES
 *
 * Optional:
 *   STAGING_TEST_EMAIL
 *   STAGING_TEST_PASSWORD
 *
 * The script creates one auth user, one country, one profile, one annual plan,
 * one billing account, one invoice, one subscription cycle and one Finance
 * obligation in the disposable environment. It does not clean up because
 * subscription cycles are intentionally append-only. Use only a disposable
 * preview/staging database.
 *
 * It does not test M-Pesa, settlement, payout, referral rewards or periods.
 */

import crypto from 'node:crypto';

const PRODUCTION_REF = 'erbxiqdfjmqnoeyjupru';
const url = process.env.STAGING_SUPABASE_URL?.replace(/\/+$/, '');
const anonKey = process.env.STAGING_SUPABASE_ANON_KEY;
const serviceKey = process.env.STAGING_SUPABASE_SERVICE_ROLE_KEY;

const checks = [];
const failures = [];

function record(name, ok, detail = '') {
  checks.push({ name, ok, detail });
  if (ok) {
    console.log(`PASS  ${name}`);
  } else {
    failures.push({ name, detail });
    console.log(`FAIL  ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

function abort(message) {
  console.error(`ABORT: ${message}`);
  process.exit(2);
}

if (!url || !anonKey || !serviceKey) {
  abort(
    'STAGING_SUPABASE_URL, STAGING_SUPABASE_ANON_KEY and STAGING_SUPABASE_SERVICE_ROLE_KEY are required.',
  );
}
if (url.includes(PRODUCTION_REF)) {
  abort('Refusing to run against the known production Supabase project.');
}
if (process.env.ALLOW_STAGING_RPC_VERIFICATION !== 'YES') {
  abort(
    'Set ALLOW_STAGING_RPC_VERIFICATION=YES only for a disposable staging/preview environment.',
  );
}

const serviceHeaders = {
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`,
  'Content-Type': 'application/json',
};

function parseBody(text, contentType) {
  if (!text) return null;
  if ((contentType || '').includes('application/json')) {
    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  }
  return text;
}

async function request(path, options = {}) {
  const response = await fetch(`${url}${path}`, options);
  const text = await response.text();
  return {
    status: response.status,
    ok: response.ok,
    body: parseBody(text, response.headers.get('content-type')),
  };
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
  return request(`/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: headersFor(token, schema),
    body: JSON.stringify(body ?? {}),
  });
}

async function insertRow(schema, table, row, token = serviceKey) {
  return request(`/rest/v1/${table}`, {
    method: 'POST',
    headers: headersFor(token, schema, { Prefer: 'return=representation' }),
    body: JSON.stringify(row),
  });
}

async function updateRows(schema, table, filter, patch, token) {
  return request(`/rest/v1/${table}?${filter}`, {
    method: 'PATCH',
    headers: headersFor(token, schema, { Prefer: 'return=representation' }),
    body: JSON.stringify(patch),
  });
}

async function selectRows(schema, table, query, token = serviceKey) {
  return request(`/rest/v1/${table}?${query}`, {
    method: 'GET',
    headers: headersFor(token, schema),
  });
}

function firstRow(body, name) {
  if (Array.isArray(body) && body.length > 0) return body[0];
  if (body && typeof body === 'object' && !Array.isArray(body)) return body;
  throw new Error(`${name}: expected a row, received ${JSON.stringify(body)}`);
}

function expectDenied(name, response) {
  record(
    name,
    !response.ok,
    response.ok
      ? `unexpectedly succeeded with ${JSON.stringify(response.body)}`
      : `denied with HTTP ${response.status}: ${JSON.stringify(response.body)}`,
  );
}

function expectDeniedOrNoRows(name, response) {
  const rows = Array.isArray(response.body) ? response.body.length : 0;
  const denied = !response.ok || rows === 0;
  record(
    name,
    denied,
    response.ok
      ? `HTTP ${response.status}, rows changed: ${rows}`
      : `denied with HTTP ${response.status}: ${JSON.stringify(response.body)}`,
  );
}

const suffix = `${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
const email =
  process.env.STAGING_TEST_EMAIL || `referral-rpc-verify+${suffix}@example.com`;
const password =
  process.env.STAGING_TEST_PASSWORD ||
  `RpcVerify-${crypto.randomBytes(18).toString('base64url')}`;
const planKey = `verify-annual-${suffix}`;
const idempotencyKey = `verify-purchase-${suffix}`;

let userToken = '';
let profileId = '';
let userId = '';
let billingAccountId = '';
let billingEntityId = '';
let planId = '';
let invoiceNumber = '';
let purchase = null;

try {
  // -------------------------------------------------------------------------
  // A. Authenticate a test user/profile.
  // -------------------------------------------------------------------------
  const createUser = await request('/auth/v1/admin/users', {
    method: 'POST',
    headers: serviceHeaders,
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { purpose: 'referral-rpc-verification' },
    }),
  });
  if (!createUser.ok) {
    abort(`auth admin create user failed: ${createUser.status} ${JSON.stringify(createUser.body)}`);
  }
  userId = createUser.body.id;
  record('auth admin creates test user', Boolean(userId), userId);

  const signIn = await request('/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: { apikey: anonKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!signIn.ok || !signIn.body?.access_token) {
    abort(`password sign-in failed: ${signIn.status} ${JSON.stringify(signIn.body)}`);
  }
  userToken = signIn.body.access_token;
  record('authenticated user token acquired', Boolean(userToken));

  const countryInsert = await insertRow('core', 'countries', {
    name: `RPC Verifyland ${suffix}`,
    iso_alpha2: 'ZZ',
    iso_alpha3: 'ZZZ',
    dialing_code: '999',
    is_active: true,
  });
  if (!countryInsert.ok) {
    abort(`country seed failed: ${countryInsert.status} ${JSON.stringify(countryInsert.body)}`);
  }
  const country = firstRow(countryInsert.body, 'country seed');

  const profileInsert = await insertRow('users', 'profiles', {
    auth_user_id: userId,
    first_name: 'RPC Verify',
    last_name: 'User',
    email,
    country_id: country.id,
    is_active: true,
    account_status: 'active',
  });
  if (!profileInsert.ok) {
    abort(`profile seed failed: ${profileInsert.status} ${JSON.stringify(profileInsert.body)}`);
  }
  const profile = firstRow(profileInsert.body, 'profile seed');
  profileId = profile.id;
  record('test profile created', Boolean(profileId), profileId);

  // -------------------------------------------------------------------------
  // B/C/D. Billing account creation and idempotent reuse.
  // -------------------------------------------------------------------------
  const firstAccount = await rpc(
    'system',
    'ensure_individual_billing_account',
    {},
    userToken,
  );
  record(
    'authenticated RPC creates billing account',
    firstAccount.ok,
    `${firstAccount.status} ${JSON.stringify(firstAccount.body)}`,
  );

  const account = firstRow(firstAccount.body, 'billing account');
  billingAccountId = account.billing_account_id;
  billingEntityId = account.entity_id;
  record(
    'billing account is individual/KES/active',
    account.account_type === 'individual' &&
      account.currency === 'KES' &&
      account.status === 'active',
    JSON.stringify(account),
  );
  record(
    'billing account belongs to caller profile',
    account.profile_id === profileId,
    `${account.profile_id} vs ${profileId}`,
  );

  const accountRows = await selectRows(
    'system',
    'billing_accounts',
    `profile_id=eq.${profileId}&select=id,entity_id,profile_id,account_type,currency,status`,
  );
  record(
    'exactly one billing account exists for profile',
    accountRows.ok && Array.isArray(accountRows.body) && accountRows.body.length === 1,
    JSON.stringify(accountRows.body),
  );

  const secondAccount = await rpc(
    'system',
    'ensure_individual_billing_account',
    {},
    userToken,
  );
  const accountRetry = firstRow(secondAccount.body, 'billing account retry');
  record(
    'billing account is reused idempotently',
    secondAccount.ok &&
      accountRetry.billing_account_id === billingAccountId &&
      accountRetry.entity_id === billingEntityId,
    JSON.stringify(accountRetry),
  );

  // -------------------------------------------------------------------------
  // E/F. Service-role invoice allocation.
  // -------------------------------------------------------------------------
  const allocA = await rpc('system', 'allocate_invoice_number', {}, serviceKey);
  const allocB = await rpc('system', 'allocate_invoice_number', {}, serviceKey);
  record(
    'service role allocates invoice numbers',
    allocA.ok && allocB.ok,
    `${allocA.status}/${allocB.status} ${JSON.stringify([allocA.body, allocB.body])}`,
  );
  const n1 = String(allocA.body ?? '');
  const n2 = String(allocB.body ?? '');
  invoiceNumber = n1;
  record(
    'invoice allocations are unique and ordered',
    n1.length > 0 &&
      n2.length > 0 &&
      n1 !== n2 &&
      Number(n2) > Number(n1),
    `${n1} then ${n2}`,
  );

  // -------------------------------------------------------------------------
  // G. Create/use a yearly KES test plan.
  // -------------------------------------------------------------------------
  const planResult = await rpc(
    'system',
    'create_annual_subscription_plan',
    {
      p_plan_key: planKey,
      p_plan_name: `RPC Verify Annual ${suffix}`,
      p_amount: 12000,
      p_module_key: null,
      p_features_json: {},
    },
    serviceKey,
  );
  const plan = firstRow(planResult.body, 'annual plan');
  planId = plan.plan_id;
  record(
    'yearly KES test plan created/reused',
    planResult.ok && Boolean(planId),
    JSON.stringify(plan),
  );

  // -------------------------------------------------------------------------
  // H/I. Annual purchase and row verification.
  // -------------------------------------------------------------------------
  const purchaseResult = await rpc(
    'finance',
    'create_annual_subscription',
    {
      p_billing_account_id: billingAccountId,
      p_plan_id: planId,
      p_invoice_number: invoiceNumber,
      p_idempotency_key: idempotencyKey,
      p_requested_start_date: null,
      p_due_at: null,
    },
    serviceKey,
  );
  purchase = firstRow(purchaseResult.body, 'annual purchase');
  record(
    'annual purchase RPC succeeds',
    purchaseResult.ok && Boolean(purchase.subscription_cycle_id),
    JSON.stringify(purchase),
  );

  const activeSub = await selectRows(
    'system',
    'active_subscriptions',
    `id=eq.${purchase.active_subscription_id}&select=id,billing_account_id,plan_id,status`,
  );
  record(
    'pending active_subscription created',
    activeSub.ok &&
      Array.isArray(activeSub.body) &&
      activeSub.body.length === 1 &&
      activeSub.body[0].status === 'pending' &&
      activeSub.body[0].billing_account_id === billingAccountId &&
      activeSub.body[0].plan_id === planId,
    JSON.stringify(activeSub.body),
  );

  const invoice = await selectRows(
    'system',
    'invoices',
    `id=eq.${purchase.invoice_id}&select=id,billing_account_id,invoice_number,status,total_amount,currency`,
  );
  record(
    'invoice created with allocated number',
    invoice.ok &&
      Array.isArray(invoice.body) &&
      invoice.body.length === 1 &&
      invoice.body[0].invoice_number === invoiceNumber &&
      invoice.body[0].status === 'pending' &&
      invoice.body[0].total_amount === 12000 &&
      invoice.body[0].currency === 'KES',
    JSON.stringify(invoice.body),
  );

  const items = await selectRows(
    'system',
    'invoice_items',
    `invoice_id=eq.${purchase.invoice_id}&select=id,invoice_id,item_type,total_amount`,
  );
  record(
    'invoice item created',
    items.ok &&
      Array.isArray(items.body) &&
      items.body.length === 1 &&
      items.body[0].item_type === 'subscription' &&
      items.body[0].total_amount === 12000,
    JSON.stringify(items.body),
  );

  const obligation = await selectRows(
    'finance',
    'obligations',
    `id=eq.${purchase.obligation_id}&select=id,obligation_type,amount,currency,metadata`,
  );
  record(
    'Finance subscription obligation created',
    obligation.ok &&
      Array.isArray(obligation.body) &&
      obligation.body.length === 1 &&
      obligation.body[0].obligation_type === 'subscription' &&
      obligation.body[0].amount === 12000 &&
      obligation.body[0].currency === 'KES' &&
      obligation.body[0].metadata?.finance_charge_code === 'subscription',
    JSON.stringify(obligation.body),
  );

  record(
    'permanent annual cycle created',
    purchaseResult.ok &&
      purchase.annual_sequence === 1 &&
      purchase.cycle_type === 'initial_annual' &&
      purchase.status === 'pending' &&
      Boolean(purchase.subscription_cycle_id) &&
      Boolean(purchase.invoice_id) &&
      Boolean(purchase.obligation_id) &&
      purchase.amount === 12000 &&
      purchase.currency === 'KES',
    JSON.stringify(purchase),
  );

  // -------------------------------------------------------------------------
  // J. Idempotent purchase retry.
  // -------------------------------------------------------------------------
  const retry = await rpc(
    'finance',
    'create_annual_subscription',
    {
      p_billing_account_id: billingAccountId,
      p_plan_id: planId,
      p_invoice_number: invoiceNumber,
      p_idempotency_key: idempotencyKey,
      p_requested_start_date: null,
      p_due_at: null,
    },
    serviceKey,
  );
  const retryPurchase = firstRow(retry.body, 'annual purchase retry');
  record(
    'purchase retry returns the same cycle',
    retry.ok &&
      retryPurchase.subscription_cycle_id === purchase.subscription_cycle_id &&
      retryPurchase.invoice_id === purchase.invoice_id &&
      retryPurchase.obligation_id === purchase.obligation_id,
    JSON.stringify(retryPurchase),
  );

  const invoiceCount = await selectRows(
    'system',
    'invoices',
    `invoice_number=eq.${encodeURIComponent(invoiceNumber)}&select=id`,
  );
  record(
    'idempotent retry creates no duplicate invoice',
    retry.ok &&
      invoiceCount.ok &&
      Array.isArray(invoiceCount.body) &&
      invoiceCount.body.length === 1,
    `invoices=${JSON.stringify(invoiceCount.body)}`,
  );

  // -------------------------------------------------------------------------
  // Security checks (authenticated client context).
  // -------------------------------------------------------------------------
  const arbitraryProfile = crypto.randomUUID();
  const arbitraryEntity = crypto.randomUUID();

  const arbitraryAccount = await rpc(
    'system',
    'ensure_individual_billing_account',
    { p_profile_id: arbitraryProfile, p_entity_id: arbitraryEntity },
    userToken,
  );
  expectDenied(
    'authenticated cannot supply arbitrary profile/entity IDs to billing RPC',
    arbitraryAccount,
  );

  const directBillingInsert = await insertRow(
    'system',
    'billing_accounts',
    {
      entity_id: arbitraryEntity,
      profile_id: arbitraryProfile,
      account_type: 'individual',
      currency: 'KES',
      status: 'active',
    },
    userToken,
  );
  expectDenied(
    'authenticated cannot directly insert billing account',
    directBillingInsert,
  );

  const clientAllocator = await rpc(
    'system',
    'allocate_invoice_number',
    {},
    userToken,
  );
  expectDenied(
    'authenticated cannot call allocate_invoice_number',
    clientAllocator,
  );

  const directInvoiceInsert = await insertRow(
    'system',
    'invoices',
    {
      billing_account_id: billingAccountId,
      invoice_number: `CLIENT-INVOICE-${suffix}`,
      module_name: 'subscription',
      status: 'pending',
      total_amount: 1,
      currency: 'KES',
    },
    userToken,
  );
  expectDenied(
    'authenticated cannot directly insert invoice',
    directInvoiceInsert,
  );

  const directInvoiceUpdate = await updateRows(
    'system',
    'invoices',
    `id=eq.${purchase.invoice_id}`,
    { status: 'paid' },
    userToken,
  );
  expectDeniedOrNoRows(
    'authenticated cannot directly update invoice',
    directInvoiceUpdate,
  );

  const directObligationInsert = await insertRow(
    'finance',
    'obligations',
    {
      payer_entity_id: billingEntityId,
      payee_entity_id: billingEntityId,
      obligation_type: 'other',
      amount: 1,
      currency: 'KES',
      idempotency_key: `client-obligation-${suffix}`,
      metadata: {},
    },
    userToken,
  );
  expectDenied(
    'authenticated cannot directly insert Finance obligation',
    directObligationInsert,
  );

  const directCycleInsert = await insertRow(
    'finance',
    'subscription_cycles',
    {
      billing_account_id: billingAccountId,
      subscriber_profile_id: profileId,
      entity_id: billingEntityId,
      plan_id: planId,
      annual_sequence: 99,
      cycle_type: 'initial_annual',
      period_start: '2026-01-01',
      period_end: '2026-12-31',
      invoice_id: purchase.invoice_id,
      obligation_id: purchase.obligation_id,
      amount: 1,
      currency: 'KES',
      status: 'pending',
      idempotency_key: `client-cycle-${suffix}`,
    },
    userToken,
  );
  expectDenied(
    'authenticated cannot directly insert subscription cycle',
    directCycleInsert,
  );

  const directCycleUpdate = await updateRows(
    'finance',
    'subscription_cycles',
    `id=eq.${purchase.subscription_cycle_id}`,
    { status: 'active' },
    userToken,
  );
  expectDeniedOrNoRows(
    'authenticated cannot directly update subscription cycle',
    directCycleUpdate,
  );

  const directReferralInsert = await insertRow(
    'referrals',
    'referrals',
    {
      referrer_profile_id: profileId,
      referred_profile_id: arbitraryProfile,
      referral_code: `CLIENT-${suffix}`,
      attribution_method: 'code',
      status: 'attributed',
    },
    userToken,
  );
  expectDenied(
    'authenticated cannot directly insert referral record',
    directReferralInsert,
  );
} catch (error) {
  record('verification execution', false, String(error?.stack || error));
}

console.log('\nVerification summary');
for (const c of checks) {
  console.log(`${c.ok ? 'PASS' : 'FAIL'}  ${c.name}`);
}
if (failures.length > 0) {
  console.error(`\n${failures.length} check(s) failed.`);
  process.exit(1);
}
console.log(`\nAll ${checks.length} checks passed.`);
console.log(
  'Test data was intentionally left in the disposable environment because subscription cycles are append-only.',
);
