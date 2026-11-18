#!/usr/bin/env node
import crypto from 'node:crypto';

const PROD='erbxiqdfjmqnoeyjupru', STAGING='ivcddanirifujxtexmzh';
const url=(process.env.STAGING_SUPABASE_URL||'').replace(/\/+$/,'');
const anon=process.env.STAGING_SUPABASE_ANON_KEY, service=process.env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
const mgmt=process.env.STAGING_MANAGEMENT_TOKEN;
if(!url||!anon||!service||!mgmt){console.error('ABORT missing staging env');process.exit(2);}
if(new URL(url).hostname.split('.')[0]!==STAGING){console.error('ABORT unexpected project');process.exit(2);}
const checks=[], failures=[];
function rec(n,ok,d=''){checks.push({n,ok,d});console.log(`${ok?'PASS':'FAIL'}  ${n}${!ok&&d?' — '+d:''}`);if(!ok)failures.push({n,d});}
async function req(path,o={}){const r=await fetch(url+path,o);const t=await r.text();let b=t;try{b=JSON.parse(t)}catch{}return{status:r.status,ok:r.ok,body:b};}
function h(token,schema,extra={}){return{apikey:token===service?service:anon,Authorization:`Bearer ${token}`,'Content-Type':'application/json',...(schema?{'Content-Profile':schema,'Accept-Profile':schema}:{}),...extra};}
async function rpc(schema,fn,body,token=service){return req(`/rest/v1/rpc/${fn}`,{method:'POST',headers:h(token,schema),body:JSON.stringify(body||{})});}
async function insert(schema,table,row,token=service){return req(`/rest/v1/${table}`,{method:'POST',headers:h(token,schema,{Prefer:'return=representation'}),body:JSON.stringify(row)});}
async function select(schema,table,q,token=service){return req(`/rest/v1/${table}?${q}`,{method:'GET',headers:h(token,schema)});}
function first(b,n){if(Array.isArray(b)&&b.length)return b[0];if(b&&typeof b==='object'&&!Array.isArray(b))return b;throw new Error(`${n}: ${JSON.stringify(b)}`);}
function scalar(b){return Array.isArray(b)?b[0]:b;}
async function mgmtQuery(q){const r=await fetch(`https://api.supabase.com/v1/projects/${STAGING}/database/query`,{method:'POST',headers:{Authorization:`Bearer ${mgmt}`,'Content-Type':'application/json'},body:JSON.stringify({query:q})});const t=await r.text();if(!r.ok)throw new Error(`management query ${r.status} ${t}`);return JSON.parse(t);}
const suffix=`${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
const password=`E2E-${crypto.randomBytes(16).toString('base64url')}`;
const country='00000000-0000-4000-8000-000000000101';
const platform='00000000-0000-4000-8000-000000000104';
let referrerToken='', referrerProfile='', referrerCode='', referrerEntity='', planId='', withdrawalId='';
async function createAuthProfile(label,phone,emailLabel=label){
  const email=`ref-e2e-${emailLabel}-${suffix}@example.com`;
  const u=await req('/auth/v1/admin/users',{method:'POST',headers:{apikey:service,Authorization:`Bearer ${service}`,'Content-Type':'application/json'},body:JSON.stringify({email,password,email_confirm:true})});
  if(!u.ok)throw new Error(`auth ${label}: ${u.status} ${JSON.stringify(u.body)}`);
  const p=await insert('users','profiles',{auth_user_id:u.body.id,first_name:label,last_name:'E2E',email,phone,country_id:country,is_active:true,account_status:'active'});
  if(!p.ok)throw new Error(`profile ${label}: ${p.status} ${JSON.stringify(p.body)}`);
  const s=await req('/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},body:JSON.stringify({email,password})});
  if(!s.ok||!s.body?.access_token)throw new Error(`signin ${label}: ${s.status}`);
  return {token:s.body.access_token,profile:first(p.body,'profile').id,email,phone};
}
async function activate(billing, label, i){
  const purchase=await rpc('finance','create_annual_subscription',{p_billing_account_id:billing,p_plan_id:planId,p_invoice_number:`E2E-${suffix}-${i}`,p_idempotency_key:`e2e-${suffix}-${i}`,p_requested_start_date:null,p_due_at:null},service);
  if(!purchase.ok)throw new Error(`purchase ${label}: ${purchase.status} ${JSON.stringify(purchase.body)}`);
  const p=first(purchase.body,'purchase');
  const checkout=`CHK-${suffix}-${i}`,receipt=`RCPT-${suffix}-${i}`,eventKey=`EV-${suffix}-${i}`;
  const attempt=await rpc('finance','create_payment_attempt',{p_obligation_id:p.obligation_id,p_provider:'mpesa',p_method_type:'mpesa',p_amount:p.amount,p_idempotency_key:`att-${suffix}-${i}`,p_payment_method_id:null,p_metadata:{phone:'254700000000',finance_charge_code:'subscription'}},service);
  if(!attempt.ok)throw new Error(`attempt ${label}: ${attempt.status} ${JSON.stringify(attempt.body)}`);
  const attemptId=scalar(attempt.body);
  const claim=await rpc('finance','claim_mpesa_attempt_safe',{p_payment_attempt_id:attemptId},globalThis.currentToken);
  if(!claim.ok)throw new Error(`claim ${label}: ${claim.status} ${JSON.stringify(claim.body)}`);
  const init=await rpc('finance','complete_mpesa_initiation',{p_payment_attempt_id:attemptId,p_checkout_request_id:checkout,p_failure_code:null,p_failure_message:null},service);
  if(!init.ok)throw new Error(`init ${label}: ${init.status} ${JSON.stringify(init.body)}`);
  const verifiedAt=new Date().toISOString();
  const callback={Body:{stkCallback:{ResultCode:0,ResultDesc:'Success',CheckoutRequestID:checkout,CallbackMetadata:{Item:[{Name:'MpesaReceiptNumber',Value:receipt},{Name:'Amount',Value:Number(p.amount)}]}}}};
  const query={ResponseCode:'0',ResultCode:'0',ResultDesc:'Success',CheckoutRequestID:checkout};
  const ev=await rpc('finance','record_mpesa_verification_evidence',{p_payment_attempt_id:attemptId,p_provider_event_id:eventKey,p_verified_provider_reference:receipt,p_verified_amount:p.amount,p_verified_currency:'KES',p_callback_payload:callback,p_provider_query_result:query,p_provider_verified_at:verifiedAt},service);
  if(!ev.ok)throw new Error(`evidence ${label}: ${ev.status} ${JSON.stringify(ev.body)}`);
  const eventId=scalar(ev.body);
  const fin=await rpc('finance','finalize_mpesa_payment',{p_payment_attempt_id:attemptId,p_provider_event_id:eventId},service);
  if(!fin.ok)throw new Error(`finalize ${label}: ${fin.status} ${JSON.stringify(fin.body)}`);
  const act=await rpc('finance','complete_annual_subscription',{p_subscription_cycle_id:p.subscription_cycle_id,p_obligation_id:p.obligation_id},service);
  if(!act.ok)throw new Error(`activate ${label}: ${act.status} ${JSON.stringify(act.body)}`);
  return {purchase:p,eventId:first(act.body,'activation').event_id,paymentId:scalar(fin.body)};
}
try{
  const eng=await rpc('finance','ensure_referral_accounts',{p_platform_entity_id:platform,p_payable_account_code:'2400',p_payable_account_name:'Staging Referral Rewards Payable'},service);
  rec('referral accounts ready',eng.ok,JSON.stringify(eng.body));
  const plan=await rpc('system','create_annual_subscription_plan',{p_plan_key:`e2e-referral-${suffix}`,p_plan_name:`E2E Referral ${suffix}`,p_amount:12000,p_module_key:null,p_features_json:{}},service);
  if(!plan.ok)throw new Error(`plan ${plan.status} ${JSON.stringify(plan.body)}`); planId=first(plan.body,'plan').plan_id;
  const ref=await createAuthProfile('Referrer',`+254755${suffix.replace(/\D/g,'').slice(-6)}`);
  referrerToken=ref.token; referrerProfile=ref.profile; globalThis.currentToken=referrerToken;
  const codeRes=await rpc('referrals','get_or_create_referral_code',{},referrerToken); referrerCode=Array.isArray(codeRes.body)?codeRes.body[0]:codeRes.body; if(typeof referrerCode==='object')referrerCode=referrerCode?.referral_code;
  const refBilling=await rpc('system','ensure_individual_billing_account',{},referrerToken);
  if(!refBilling.ok)throw new Error(`referrer billing ${refBilling.status} ${JSON.stringify(refBilling.body)}`);
  referrerEntity=first(refBilling.body,'referrer billing').entity_id;
  const rewards=[];
  for(let i=1;i<=13;i++){
    const u=await createAuthProfile(`Referred${i}`,`+254756${String(i).padStart(6,'0')}${suffix.replace(/\D/g,'').slice(-2)}`);
    const billing=await rpc('system','ensure_individual_billing_account',{},u.token);
    if(!billing.ok)throw new Error(`billing ${i}: ${billing.status} ${JSON.stringify(billing.body)}`); const b=first(billing.body,'billing');
    const reg=await rpc('referrals','register_referral',{p_referral_code:referrerCode,p_attribution_session_id:null,p_phone:u.phone,p_email:u.email},u.token);
    if(!reg.ok)throw new Error(`register ${i}: ${reg.status} ${JSON.stringify(reg.body)}`);
    globalThis.currentToken=u.token;
    const completed=await activate(b.billing_account_id,`Referred${i}`,i);
    const cons=await rpc('referrals','consume_finance_event',{p_event_id:completed.eventId},service);
    const crow=first(cons.body,'consume'); rec(`referred ${i} reward created`,cons.ok&&crow.outcome==='rewarded'&&Boolean(crow.reward_id),JSON.stringify(cons.body)); rewards.push({i,eventId:completed.eventId,rewardId:crow.reward_id,user:u});
    globalThis.currentToken=referrerToken;
    if(i===12){const bal=await rpc('referrals','get_reward_balance',{},referrerToken); rec('twelve rewards balance is 480',bal.ok&&Number(scalar(bal.body))===480,JSON.stringify(bal.body)); const tooSmall=await rpc('referrals','request_withdrawal',{p_amount:480,p_idempotency_key:`e2e-small-${suffix}`},referrerToken); rec('withdrawal below KSh 500 rejected',!tooSmall.ok,`${tooSmall.status} ${JSON.stringify(tooSmall.body)}`);}
  }
  // Renewal for first referred.
  const firstUser=rewards[0].user; globalThis.currentToken=firstUser.token;
  const renewalBilling=await rpc('system','ensure_individual_billing_account',{},firstUser.token); const rb=first(renewalBilling.body,'billing');
  const renewal=await activate(rb.billing_account_id,'Renewal',999);
  const renewalCons=await rpc('referrals','consume_finance_event',{p_event_id:renewal.eventId},service);
  rec('renewal activation excluded',renewalCons.ok&&first(renewalCons.body,'renewal').outcome==='renewal_excluded',JSON.stringify(renewalCons.body));
  // Duplicate event.
  const dup=await rpc('referrals','consume_finance_event',{p_event_id:rewards[0].eventId},service); rec('duplicate activation does not add reward',dup.ok&&first(dup.body,'dup').outcome==='already_processed',JSON.stringify(dup.body));
  // Self and ambiguous.
  const selfPhone='+2547'+crypto.randomInt(10000000,99999999); const self=await createAuthProfile('SelfAttempt',selfPhone); const selfReg=await rpc('referrals','register_referral',{p_referral_code:referrerCode,p_attribution_session_id:null,p_phone:ref.phone,p_email:self.email},self.token); rec('self referral rejected',selfReg.ok&&first(selfReg.body,'self').referral_status==='ineligible',JSON.stringify(selfReg.body));
  const ambPhone='+2547'+crypto.randomInt(10000000,99999999); const amb=await createAuthProfile('Referrer',ambPhone,'Ambiguous'); const ambReg=await rpc('referrals','register_referral',{p_referral_code:referrerCode,p_attribution_session_id:null,p_phone:amb.phone,p_email:amb.email},amb.token); rec('ambiguous referral held for review',ambReg.ok&&first(ambReg.body,'amb').referral_status==='review_required',JSON.stringify(ambReg.body));
  // Vunio employee fixture via staging control plane only.
  const empPhone='+2547'+crypto.randomInt(10000000,99999999); const emp=await createAuthProfile('Employee',empPhone); const empBilling=await rpc('system','ensure_individual_billing_account',{},emp.token); const eb=first(empBilling.body,'billing');
  await rpc('referrals','register_referral',{p_referral_code:referrerCode,p_attribution_session_id:null,p_phone:emp.phone,p_email:emp.email},emp.token);
  await mgmtQuery(`insert into referrals.employee_exclusions (profile_id, employer_entity_id, employment_start_at, reason, created_by) values ('${emp.profile}','${platform}', now() - interval '1 hour','Vunio employee','00000000-0000-4000-8000-000000000103')`);
  globalThis.currentToken=emp.token; const empEvent=await activate(eb.billing_account_id,'EmployeeCase',2000); const empCons=await rpc('referrals','consume_finance_event',{p_event_id:empEvent.eventId},service); rec('Vunio employee exclusion via consumer',empCons.ok&&first(empCons.body,'emp').outcome==='employee_excluded',JSON.stringify(empCons.body));
  // Balance and concurrent withdrawal.
  const bal=await rpc('referrals','get_reward_balance',{},referrerToken); rec('thirteen rewards balance is 520',bal.ok&&Number(scalar(bal.body))===520,JSON.stringify(bal.body));
  const [w1,w2]=await Promise.all([rpc('referrals','request_withdrawal',{p_amount:520,p_idempotency_key:`e2e-w1-${suffix}`},referrerToken),rpc('referrals','request_withdrawal',{p_amount:520,p_idempotency_key:`e2e-w2-${suffix}`},referrerToken)]);
  const winners=[w1,w2].filter(x=>x.ok); rec('exactly one concurrent withdrawal wins',winners.length===1,JSON.stringify([w1,w2])); withdrawalId=first(winners[0].body,'withdrawal').withdrawal_request_id;
  const dupW=await rpc('referrals','request_withdrawal',{p_amount:520,p_idempotency_key:`e2e-w3-${suffix}`},referrerToken); rec('duplicate open withdrawal rejected',!dupW.ok,`${dupW.status} ${JSON.stringify(dupW.body)}`);
  // Approve and payout.
  const approve=await rpc('referrals','approve_withdrawal',{p_request_id:withdrawalId,p_recipient_entity_id:referrerEntity,p_notes:'staging e2e'},service); rec('withdrawal approved with Finance obligation',approve.ok,JSON.stringify(approve.body));
  const payout=await rpc('referrals','record_manual_payout',{p_request_id:withdrawalId,p_mpesa_receipt:`E2E-RECEIPT-${suffix}`,p_payout_evidence:{channel:'manual_staging'},p_paid_at:new Date().toISOString()},service); rec('manual payout reconciled',payout.ok,JSON.stringify(payout.body));
  const payRetry=await rpc('referrals','record_manual_payout',{p_request_id:withdrawalId,p_mpesa_receipt:`E2E-RECEIPT-${suffix}`,p_payout_evidence:{channel:'manual_staging'},p_paid_at:new Date().toISOString()},service); rec('same payout receipt idempotent',payRetry.ok,JSON.stringify(payRetry.body));
  const paySecond=await rpc('referrals','record_manual_payout',{p_request_id:withdrawalId,p_mpesa_receipt:`E2E-RECEIPT-OTHER-${suffix}`,p_payout_evidence:{channel:'manual_staging'},p_paid_at:new Date().toISOString()},service); rec('different payout receipt rejected',!paySecond.ok,`${paySecond.status} ${JSON.stringify(paySecond.body)}`);
  const after=await rpc('referrals','get_reward_balance',{},referrerToken); rec('balance zero after withdrawal',after.ok&&Number(scalar(after.body))===0,JSON.stringify(after.body));
  console.log('IDS',JSON.stringify({referrerProfile,referrerEntity,withdrawalId,rewards:rewards.map(r=>({i:r.i,rewardId:r.rewardId,eventId:r.eventId}))}));
}catch(e){rec('verification execution',false,String(e?.stack||e));}
console.log(`\n${checks.filter(c=>c.ok).length} passed, ${failures.length} failed`); for(const f of failures)console.error(`FAIL ${f.n}: ${f.d}`); process.exit(failures.length?1:0);
