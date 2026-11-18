-- ============================================================================
-- referrals_platform_admin_authority_test.sql
-- LOCAL-ONLY Phase 1 platform-admin authority and actor-audit tests.
-- ============================================================================
BEGIN;

UPDATE referrals.program_settings SET foundation_activation_enabled=true;

INSERT INTO users.profiles (id,auth_user_id,first_name,country_id,is_active,account_status)
VALUES
 ('70000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001','Admin A',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('70000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000002','Admin B',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('70000000-0000-4000-8000-000000000003','71000000-0000-4000-8000-000000000003','Non Admin',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('70000000-0000-4000-8000-000000000004','71000000-0000-4000-8000-000000000004','Suspended User',
  (SELECT id FROM core.countries LIMIT 1),true,'suspended'),
 ('70000000-0000-4000-8000-000000000005','71000000-0000-4000-8000-000000000005','Blocked User',
  (SELECT id FROM core.countries LIMIT 1),true,'blocked'),
 ('70000000-0000-4000-8000-000000000006','71000000-0000-4000-8000-000000000006','Inactive User',
  (SELECT id FROM core.countries LIMIT 1),false,'active'),
 ('70000000-0000-4000-8000-000000000007',NULL,'Beneficiary',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('70000000-0000-4000-8000-000000000008',NULL,'Referred One',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('70000000-0000-4000-8000-000000000009',NULL,'Referred Two',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('70000000-0000-4000-8000-000000000010',NULL,'Referred Three',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('70000000-0000-4000-8000-000000000011',NULL,'Referred Four',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('70000000-0000-4000-8000-000000000012',NULL,'Reassign Target',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('70000000-0000-4000-8000-000000000013','71000000-0000-4000-8000-000000000013','Super Admin User',
  (SELECT id FROM core.countries LIMIT 1),true,'active'),
 ('70000000-0000-4000-8000-000000000014','71000000-0000-4000-8000-000000000014','Business Admin User',
  (SELECT id FROM core.countries LIMIT 1),true,'active');

INSERT INTO core.entities (id,name,entity_type,owner_id,is_active,metadata)
VALUES ('72000000-0000-4000-8000-000000000001','Beneficiary Entity','individual_pro',
        '70000000-0000-4000-8000-000000000007',true,'{}'::jsonb);

-- Ensure the existing production administration roles exist in this local
-- fixture. The migration must not create a new platform_admin role.
INSERT INTO core.user_roles (name,type,description,is_active)
SELECT 'Admin','administration','Existing platform administration role',true
WHERE NOT EXISTS (SELECT 1 FROM core.user_roles WHERE name='Admin');
INSERT INTO core.user_roles (name,type,description,is_active)
SELECT 'Super Admin','administration','Existing super administration role',true
WHERE NOT EXISTS (SELECT 1 FROM core.user_roles WHERE name='Super Admin');

-- Admin A/B, plus suspended/blocked/inactive Admin holders, are assigned on the
-- canonical platform entity. The non-admin has no assignment.
INSERT INTO core.entity_roles (profile_id,entity_id,role_id,assigned_by,is_active)
SELECT p.id, '00000000-0000-4000-8000-000000000104', r.id,
       '00000000-0000-4000-8000-000000000103', true
  FROM users.profiles p
  JOIN core.user_roles r ON r.name='Admin'
 WHERE p.id IN (
   '70000000-0000-4000-8000-000000000001',
   '70000000-0000-4000-8000-000000000002',
   '70000000-0000-4000-8000-000000000004',
   '70000000-0000-4000-8000-000000000005',
   '70000000-0000-4000-8000-000000000006'
 )
ON CONFLICT (profile_id,entity_id,role_id) DO NOTHING;

-- Super Admin on the canonical entity is intentionally NOT sufficient for this
-- phase because the existing production Super Admin role has no admin.* grants.
INSERT INTO core.entity_roles (profile_id,entity_id,role_id,assigned_by,is_active)
SELECT '70000000-0000-4000-8000-000000000013',
       '00000000-0000-4000-8000-000000000104', id,
       '00000000-0000-4000-8000-000000000103', true
  FROM core.user_roles WHERE name='Super Admin'
ON CONFLICT (profile_id,entity_id,role_id) DO NOTHING;

INSERT INTO core.entity_members (entity_id,profile_id,role_id,is_active,membership_status)
SELECT '00000000-0000-4000-8000-000000000104', p.id, r.id, true, 'active'
  FROM users.profiles p
  JOIN core.user_roles r ON r.name='Admin'
 WHERE p.id IN (
   '70000000-0000-4000-8000-000000000001',
   '70000000-0000-4000-8000-000000000002',
   '70000000-0000-4000-8000-000000000004',
   '70000000-0000-4000-8000-000000000005',
   '70000000-0000-4000-8000-000000000006'
 )
ON CONFLICT (entity_id,profile_id) DO UPDATE
SET role_id = EXCLUDED.role_id, is_active = true, membership_status = 'active';

INSERT INTO core.entity_members (entity_id,profile_id,role_id,is_active,membership_status)
SELECT '00000000-0000-4000-8000-000000000104',
       '70000000-0000-4000-8000-000000000013', id, true, 'active'
  FROM core.user_roles WHERE name='Super Admin'
ON CONFLICT (entity_id,profile_id) DO UPDATE
SET role_id = EXCLUDED.role_id, is_active = true, membership_status = 'active';

-- Admin on an ordinary entity must not confer platform administration.
INSERT INTO core.entities (id,name,entity_type,owner_id,is_active,metadata)
VALUES ('72000000-0000-4000-8000-000000000002','Ordinary Business Entity','individual_pro',
        '70000000-0000-4000-8000-000000000014',true,'{}'::jsonb);
INSERT INTO core.entity_roles (profile_id,entity_id,role_id,assigned_by,is_active)
SELECT '70000000-0000-4000-8000-000000000014',
       '72000000-0000-4000-8000-000000000002', id,
       '00000000-0000-4000-8000-000000000103', true
  FROM core.user_roles WHERE name='Admin'
ON CONFLICT (profile_id,entity_id,role_id) DO NOTHING;

INSERT INTO core.entity_members (entity_id,profile_id,role_id,is_active,membership_status)
SELECT '72000000-0000-4000-8000-000000000002',
       '70000000-0000-4000-8000-000000000014', id, true, 'active'
  FROM core.user_roles WHERE name='Admin'
ON CONFLICT (entity_id,profile_id) DO UPDATE
SET role_id = EXCLUDED.role_id, is_active = true, membership_status = 'active';

INSERT INTO referrals.referrals (id,referrer_profile_id,referred_profile_id,referral_code,attribution_method,status)
VALUES
 ('73000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000008','ADMIN-CASE-1','code','review_required'),
 ('73000000-0000-4000-8000-000000000002','70000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000009','ADMIN-CASE-2','code','review_required'),
 ('73000000-0000-4000-8000-000000000003','70000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000010','ADMIN-CASE-3','code','review_required'),
 ('73000000-0000-4000-8000-000000000004','70000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000011','ADMIN-CASE-4','code','review_required');

INSERT INTO referrals.review_cases (id,referral_id,case_type,status,notes)
VALUES
 ('74000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000001','self_referral','open','denial case'),
 ('74000000-0000-4000-8000-000000000002','73000000-0000-4000-8000-000000000002','self_referral','open','service case'),
 ('74000000-0000-4000-8000-000000000003','73000000-0000-4000-8000-000000000003','self_referral','open','service nonadmin case'),
 ('74000000-0000-4000-8000-000000000004','73000000-0000-4000-8000-000000000004','self_referral','open','spoof case');

INSERT INTO referrals.referrals (id,referrer_profile_id,referred_profile_id,referral_code,attribution_method,status)
VALUES ('73000000-0000-4000-8000-000000000005','70000000-0000-4000-8000-000000000001',
        '70000000-0000-4000-8000-000000000012','ADMIN-REASSIGN','code','attributed');

INSERT INTO referrals.withdrawal_requests (
    id,beneficiary_profile_id,amount,currency,status,idempotency_key,version
) VALUES (
    '75000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000007',
    500,'KES','requested','admin-authority-reject',1
);

-- Denials: all role holders with a non-access profile, and a non-admin.
DO $denials$
DECLARE
    v_auth text;
    v_case uuid := '74000000-0000-4000-8000-000000000001';
    v_rejected boolean;
BEGIN
    FOREACH v_auth IN ARRAY ARRAY[
        '71000000-0000-4000-8000-000000000003', -- non-admin
        '71000000-0000-4000-8000-000000000004', -- suspended
        '71000000-0000-4000-8000-000000000005', -- blocked
        '71000000-0000-4000-8000-000000000006', -- inactive
        '71000000-0000-4000-8000-000000000013', -- Super Admin, but not Admin
        '71000000-0000-4000-8000-000000000014'  -- Admin on ordinary entity only
    ] LOOP
        PERFORM set_config('request.jwt.claim.sub', v_auth, true);
        v_rejected := false;
        BEGIN
            PERFORM referrals.resolve_review_case(v_case, 'cleared', NULL);
        EXCEPTION WHEN SQLSTATE '42501' THEN
            v_rejected := true;
        END;
        IF NOT v_rejected THEN
            RAISE EXCEPTION 'non-authorized actor was accepted: %', v_auth;
        END IF;
    END LOOP;
END;
$denials$;

-- Authenticated admin cannot substitute another admin profile as actor.
DO $spoof$
DECLARE
    v_case uuid := '74000000-0000-4000-8000-000000000004';
    v_rejected boolean := false;
BEGIN
    PERFORM set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
    BEGIN
        PERFORM referrals.resolve_review_case(
            v_case, 'cleared', NULL, '70000000-0000-4000-8000-000000000002');
    EXCEPTION WHEN SQLSTATE '42501' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'authenticated admin was able to supply another actor';
    END IF;
    IF (SELECT status FROM referrals.review_cases WHERE id=v_case) <> 'open' THEN
        RAISE EXCEPTION 'spoofed actor changed review case state';
    END IF;
END;
$spoof$;

-- Active authenticated admin resolves the denial case.
DO $active_admin$
DECLARE
    v_case uuid := '74000000-0000-4000-8000-000000000001';
BEGIN
    PERFORM set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
    PERFORM referrals.resolve_review_case(v_case, 'cleared', 'active admin');
    IF NOT EXISTS (SELECT 1 FROM referrals.review_cases
                    WHERE id=v_case AND status='cleared'
                      AND resolved_by='70000000-0000-4000-8000-000000000001') THEN
        RAISE EXCEPTION 'review resolution actor was not recorded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.audit_events
                    WHERE entity_id=v_case AND event_type='review_case_resolved'
                      AND actor_profile_id='70000000-0000-4000-8000-000000000001') THEN
        RAISE EXCEPTION 'review resolution audit actor was not recorded';
    END IF;
END;
$active_admin$;

-- Active admin B reassigns before reward creation.
DO $reassign$
BEGIN
    PERFORM set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000002',true);
    PERFORM referrals.admin_reassign_referral(
        '73000000-0000-4000-8000-000000000005',
        '70000000-0000-4000-8000-000000000007',
        'authority test reassignment');
    IF NOT EXISTS (SELECT 1 FROM referrals.audit_events
                    WHERE entity_id='73000000-0000-4000-8000-000000000005'
                      AND event_type='referral_reassigned'
                      AND actor_profile_id='70000000-0000-4000-8000-000000000002') THEN
        RAISE EXCEPTION 'reassignment audit actor was not recorded';
    END IF;
END;
$reassign$;

-- Active admin rejects the withdrawal and records actor fields.
DO $reject$
BEGIN
    PERFORM set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
    PERFORM referrals.reject_withdrawal(
        '75000000-0000-4000-8000-000000000001', 'authority test reject');
    IF NOT EXISTS (SELECT 1 FROM referrals.withdrawal_requests
                    WHERE id='75000000-0000-4000-8000-000000000001'
                      AND status='rejected'
                      AND reviewed_by='70000000-0000-4000-8000-000000000001') THEN
        RAISE EXCEPTION 'withdrawal reviewer was not recorded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.withdrawal_events
                    WHERE withdrawal_request_id='75000000-0000-4000-8000-000000000001'
                      AND event_type='withdrawal_rejected'
                      AND actor_profile_id='70000000-0000-4000-8000-000000000001') THEN
        RAISE EXCEPTION 'withdrawal event actor was not recorded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM referrals.audit_events
                    WHERE entity_id='75000000-0000-4000-8000-000000000001'
                      AND event_type='withdrawal_rejected'
                      AND actor_profile_id='70000000-0000-4000-8000-000000000001') THEN
        RAISE EXCEPTION 'withdrawal audit actor was not recorded';
    END IF;
END;
$reject$;

-- Service-role path succeeds only with a supplied active platform admin.
DO $service_path$
DECLARE
    v_rejected boolean := false;
BEGIN
    PERFORM set_config('request.jwt.claim.sub','',true);
    PERFORM set_config('request.jwt.claim.role','service_role',true);

    BEGIN
        PERFORM referrals.resolve_review_case(
            '74000000-0000-4000-8000-000000000003', 'cleared', NULL,
            '70000000-0000-4000-8000-000000000003');
    EXCEPTION WHEN SQLSTATE '42501' THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'service-role path accepted a non-admin actor';
    END IF;

    PERFORM referrals.resolve_review_case(
        '74000000-0000-4000-8000-000000000002', 'cleared', NULL,
        '70000000-0000-4000-8000-000000000001');
    IF NOT EXISTS (SELECT 1 FROM referrals.review_cases
                    WHERE id='74000000-0000-4000-8000-000000000002'
                      AND status='cleared'
                      AND resolved_by='70000000-0000-4000-8000-000000000001') THEN
        RAISE EXCEPTION 'service-role admin actor was not recorded';
    END IF;
END;
$service_path$;

-- Grants: authenticated admins may execute; anon/PUBLIC may not.
DO $grants$
BEGIN
    IF NOT has_function_privilege('authenticated',
        'referrals.resolve_review_case(uuid,text,text,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated is missing admin RPC execute grant';
    END IF;
    IF has_function_privilege('anon',
        'referrals.resolve_review_case(uuid,text,text,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'anon must not execute admin RPC';
    END IF;
    IF has_function_privilege('public',
        'referrals.resolve_review_case(uuid,text,text,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'PUBLIC must not execute admin RPC';
    END IF;
END;
$grants$;

ROLLBACK;
