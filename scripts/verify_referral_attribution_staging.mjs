#!/usr/bin/env node
import crypto from 'node:crypto';
const PROD='erbxiqdfjmqnoeyjupru', STAGING='ivcddanirifujxtexmzh';
const url=(process.env.STAGING_SUPABASE_URL||'').replace(/\/+$/,'');
const anon=process.env.STAGING_SUPABASE_ANON_KEY, service=process.env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
if(!url||!anon||!service) { console.error('ABORT: staging env missing'); process.exit(2); }
if(new URL(url).hostname.split('.')[0]!==STAGING) { console.error('ABORT: unexpected project'); process.exit(2); }
const checks=[]; const failures=[];
function rec(n,ok,d=''){checks.push({n,ok,d}); console.log(`${ok?'PASS':'FAIL'}  ${n}${!ok&&d?' — '+d:''}`); if(!ok)failures.push({n,d});}
async function req(path,o={}){const r=await fetch(url+path,o); const t=await r.text(); let b=t; try{b=JSON.parse(t)}catch{} return {status:r.status,ok:r.ok,body:b};}
function h(token,schema,extra={}){return {apikey:token===service?service:anon,Authorization:`Bearer ${token}`,'Content-Type':'application/json',...(schema?{'Content-Profile':schema,'Accept-Profile':schema}:{}),...extra};}
async function rpc(schema,fn,body,token=service){return req(`/rest/v1/rpc/${fn}`,{method:'POST',headers:h(token,schema),body:JSON.stringify(body||{})});}
async function insert(schema,table,row,token=service){return req(`/rest/v1/${table}`,{method:'POST',headers:h(token,schema,{Prefer:'return=representation'}),body:JSON.stringify(row)});}
function first(b,n){if(Array.isArray(b)&&b.length)return b[0]; if(b&&typeof b==='object')return b; throw new Error(`${n}: ${JSON.stringify(b)}`);}
const suffix=`${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
const refPhone='+2547'+crypto.randomInt(10000000,99999999);
const referredPhone='+2547'+crypto.randomInt(10000000,99999999);
const ambPhone='+2547'+crypto.randomInt(10000000,99999999);
const selfPhone='+2547'+crypto.randomInt(10000000,99999999);
const refEmail=`ref-attribution+${suffix}@example.com`, referredEmail=`referred+${suffix}@example.com`, selfEmail=`self+${suffix}@example.com`, ambEmail=`amb+${suffix}@example.com`;
const password=`Attr-${crypto.randomBytes(16).toString('base64url')}`;
let refToken='', referredToken='', refProfile='', code='';
try{
 const cu=await req('/auth/v1/admin/users',{method:'POST',headers:{apikey:service,Authorization:`Bearer ${service}`,'Content-Type':'application/json'},body:JSON.stringify({email:refEmail,password,email_confirm:true})});
 if(!cu.ok)throw new Error(`referrer auth ${cu.status} ${JSON.stringify(cu.body)}`);
 const createProfile=async(email,id,firstN,lastN,phone)=>{
   const p=await insert('users','profiles',{auth_user_id:id,first_name:firstN,last_name:lastN,email,phone,country_id:'00000000-0000-4000-8000-000000000101',is_active:true,account_status:'active'});
   if(!p.ok)throw new Error(`profile ${email}: ${p.status} ${JSON.stringify(p.body)}`); return first(p.body,'profile');
 };
 const refP=await createProfile(refEmail,cu.body.id,'Referrer','Owner',refPhone);
 refProfile=refP.id;
 const rs=await req('/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},body:JSON.stringify({email:refEmail,password})});
 if(!rs.ok||!rs.body?.access_token)throw new Error(`referrer sign-in ${rs.status} ${JSON.stringify(rs.body)}`); refToken=rs.body.access_token;
 const codeRes=await rpc('referrals','get_or_create_referral_code',{},refToken);
 const codeBody=Array.isArray(codeRes.body)?codeRes.body[0]:codeRes.body; code=typeof codeBody==='string'?codeBody:(codeBody?.referral_code||codeBody?.get_or_create_referral_code); rec('referral code generated',codeRes.ok&&typeof code==='string'&&code.length>3,JSON.stringify(codeRes.body));
 const sess=await rpc('referrals','create_attribution_session',{p_method:'code',p_phone:refPhone,p_expires_at:null},refToken);
 rec('attribution session created',sess.ok&&first(sess.body,'session').session_id,JSON.stringify(sess.body));
 const mkReferred=async(email,firstN,lastN,phone)=>{
   const u=await req('/auth/v1/admin/users',{method:'POST',headers:{apikey:service,Authorization:`Bearer ${service}`,'Content-Type':'application/json'},body:JSON.stringify({email,password,email_confirm:true})});
   if(!u.ok)throw new Error(`auth ${email}: ${u.status}`);
   const p=await createProfile(email,u.body.id,firstN,lastN,phone);
   const s=await req('/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},body:JSON.stringify({email,password})});
   if(!s.ok||!s.body?.access_token)throw new Error(`sign-in ${email}: ${s.status}`);
   return {token:s.body.access_token,profile:p.id};
 };
 const referred=await mkReferred(referredEmail,'Referred','Person',referredPhone);
 referredToken=referred.token;
 const reg=await rpc('referrals','register_referral',{p_referral_code:code,p_attribution_session_id:null,p_phone:referredPhone,p_email:referredEmail},referred.token);
 const regRow=reg.ok?first(reg.body,'referral'):null;
 rec('ordinary referral attributed',reg.ok&&regRow.referral_status==='attributed',JSON.stringify(reg.body));
 const self=await mkReferred(selfEmail,'Self','Attempt',selfPhone);
 const selfReg=await rpc('referrals','register_referral',{p_referral_code:code,p_attribution_session_id:null,p_phone:refPhone,p_email:selfEmail},self.token);
 rec('self-referral rejected',selfReg.ok&&first(selfReg.body,'self').referral_status==='ineligible',JSON.stringify(selfReg.body));
 const amb=await mkReferred(ambEmail,'Referrer','Owner',ambPhone);
 const ambReg=await rpc('referrals','register_referral',{p_referral_code:code,p_attribution_session_id:null,p_phone:ambPhone,p_email:ambEmail},amb.token);
 rec('ambiguous referral held for review',ambReg.ok&&first(ambReg.body,'amb').referral_status==='review_required',JSON.stringify(ambReg.body));
 const bal=await rpc('referrals','get_reward_balance',{},refToken);
 rec('authenticated balance accessible',bal.ok,JSON.stringify(bal.body));
 const dml=await insert('referrals','rewards',{referral_id:'00000000-0000-4000-8000-000000000000',beneficiary_profile_id:refProfile,amount:40,currency:'KES'},referred.token);
 rec('direct reward insert denied',!dml.ok,`${dml.status} ${JSON.stringify(dml.body)}`);
 const serviceOnly=await rpc('referrals','consume_finance_event',{p_event_id:crypto.randomUUID()},referred.token);
 rec('service-only consumer denied to authenticated',!serviceOnly.ok,`${serviceOnly.status} ${JSON.stringify(serviceOnly.body)}`);
 const anonResp=await req('/rest/v1/rpc/approve_withdrawal',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json','Content-Profile':'referrals'},body:JSON.stringify({p_request_id:crypto.randomUUID(),p_recipient_entity_id:crypto.randomUUID()})});
 rec('service-only admin denied to anonymous',!anonResp.ok,`${anonResp.status} ${JSON.stringify(anonResp.body)}`);
}catch(e){rec('verification execution',false,String(e?.stack||e));}
console.log(`\n${checks.filter(c=>c.ok).length} passed, ${failures.length} failed`);
for(const f of failures)console.error(`FAIL ${f.n}: ${f.d}`);
process.exit(failures.length?1:0);
