-- ============================================================================
-- 20261113000001_referrals_attribution
-- ----------------------------------------------------------------------------
-- Forward-only Refer & Earn attribution workflow.
-- Uses the existing referrals schema; no direct client table access.
-- ============================================================================

BEGIN;

ALTER TABLE "users"."profiles"
    ADD COLUMN IF NOT EXISTS "referral_code" text;
CREATE UNIQUE INDEX IF NOT EXISTS "profiles_referral_code_key"
    ON "users"."profiles" ("referral_code");

CREATE OR REPLACE FUNCTION "referrals"."normalize_phone_hash"(p_phone text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $function$
  SELECT md5(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'))
$function$;

CREATE OR REPLACE FUNCTION "referrals"."normalize_email_hash"(p_email text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $function$
  SELECT md5(lower(btrim(coalesce(p_email, ''))))
$function$;

CREATE OR REPLACE FUNCTION "referrals"."attribution_decision"(
    p_referrer_profile_id uuid,
    p_referred_profile_id uuid,
    p_phone_hash text DEFAULT NULL,
    p_email_hash text DEFAULT NULL
)
RETURNS TABLE(status text, reason text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals, users, core
AS $function$
DECLARE
    v_referrer users.profiles%ROWTYPE;
    v_referred users.profiles%ROWTYPE;
    v_referrer_phone text;
    v_referrer_email text;
    v_referred_phone text;
    v_referred_email text;
BEGIN
    IF p_referrer_profile_id = p_referred_profile_id THEN
        RETURN QUERY SELECT 'ineligible'::text, 'same_profile'::text;
        RETURN;
    END IF;

    SELECT * INTO v_referrer FROM users.profiles WHERE id = p_referrer_profile_id AND is_active IS TRUE;
    SELECT * INTO v_referred FROM users.profiles WHERE id = p_referred_profile_id AND is_active IS TRUE;
    IF v_referrer.id IS NULL OR v_referred.id IS NULL THEN
        RETURN QUERY SELECT 'ineligible'::text, 'inactive_or_missing_profile'::text;
        RETURN;
    END IF;

    v_referrer_phone := referrals.normalize_phone_hash(v_referrer.phone);
    v_referrer_email := referrals.normalize_email_hash(v_referrer.email);
    v_referred_phone := coalesce(referrals.normalize_phone_hash(v_referred.phone), p_phone_hash);
    v_referred_email := coalesce(referrals.normalize_email_hash(v_referred.email), p_email_hash);

    IF (v_referrer_phone IS NOT NULL AND v_referrer_phone <> md5('')
        AND (v_referrer_phone = v_referred_phone
             OR (p_phone_hash IS NOT NULL AND v_referrer_phone = p_phone_hash)))
       OR (v_referrer_email IS NOT NULL AND v_referrer_email <> md5('')
        AND (v_referrer_email = v_referred_email
             OR (p_email_hash IS NOT NULL AND v_referrer_email = p_email_hash)))
       OR (v_referrer.auth_user_id IS NOT NULL AND v_referrer.auth_user_id = v_referred.auth_user_id) THEN
        RETURN QUERY SELECT 'ineligible'::text, 'shared_identity_signal'::text;
        RETURN;
    END IF;

    IF lower(coalesce(v_referrer.first_name, '') || ' ' || coalesce(v_referrer.last_name, ''))
       = lower(coalesce(v_referred.first_name, '') || ' ' || coalesce(v_referred.last_name, '')) THEN
        RETURN QUERY SELECT 'review_required'::text, 'same_name_requires_review'::text;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
          FROM core.entities er
          JOIN core.entities ee ON ee.owner_id = er.owner_id
         WHERE er.owner_id = p_referrer_profile_id
           AND ee.owner_id = p_referred_profile_id
           AND er.id = ee.id
           AND er.is_active IS TRUE
           AND ee.is_active IS TRUE
    ) THEN
        RETURN QUERY SELECT 'review_required'::text, 'shared_entity_requires_review'::text;
        RETURN;
    END IF;

    RETURN QUERY SELECT 'attributed'::text, 'no_conflicting_identity_signal'::text;
END;
$function$;

CREATE OR REPLACE FUNCTION "referrals"."get_or_create_referral_code"()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals, users, core, auth
AS $function$
DECLARE
    v_profile_id uuid := core.current_profile_id();
    v_code text;
    v_attempt integer := 0;
BEGIN
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT referral_code INTO v_code FROM users.profiles WHERE id = v_profile_id FOR UPDATE;
    IF v_code IS NOT NULL AND btrim(v_code) <> '' THEN
        RETURN v_code;
    END IF;

    LOOP
        v_attempt := v_attempt + 1;
        v_code := 'REF-' || upper(substr(md5(gen_random_uuid()::text), 1, 10));
        BEGIN
            UPDATE users.profiles SET referral_code = v_code, updated_at = now()
             WHERE id = v_profile_id;
            RETURN v_code;
        EXCEPTION WHEN unique_violation THEN
            IF v_attempt >= 5 THEN
                RAISE;
            END IF;
        END;
    END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION "referrals"."create_attribution_session"(
    p_method text,
    p_phone text DEFAULT NULL,
    p_expires_at timestamp with time zone DEFAULT NULL
)
RETURNS TABLE(session_id uuid, referral_code text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals, users, core, auth
AS $function$
DECLARE
    v_profile_id uuid := core.current_profile_id();
    v_code text;
    v_session_id uuid;
BEGIN
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF p_method NOT IN ('link', 'code', 'qr', 'assisted') THEN
        RAISE EXCEPTION 'Unsupported attribution method' USING ERRCODE = '22023';
    END IF;
    v_code := referrals.get_or_create_referral_code();
    INSERT INTO referrals.attribution_sessions (
        referral_code, method, normalized_phone_hash, staff_profile_id, expires_at
    ) VALUES (
        v_code, p_method, referrals.normalize_phone_hash(p_phone), v_profile_id, p_expires_at
    ) RETURNING id INTO v_session_id;

    INSERT INTO referrals.audit_events (
        entity_type, entity_id, event_type, actor_profile_id, after_state
    ) VALUES (
        'attribution_session', v_session_id, 'attribution_session_created', v_profile_id,
        jsonb_build_object('referral_code', v_code, 'method', p_method)
    );
    RETURN QUERY SELECT v_session_id, v_code;
END;
$function$;

CREATE OR REPLACE FUNCTION "referrals"."register_referral"(
    p_referral_code text,
    p_attribution_session_id uuid DEFAULT NULL,
    p_phone text DEFAULT NULL,
    p_email text DEFAULT NULL
)
RETURNS TABLE(referral_id uuid, referral_status text, decision_reason text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals, users, core, auth
AS $function$
DECLARE
    v_referred_profile_id uuid := core.current_profile_id();
    v_referrer_id uuid;
    v_method text := 'code';
    v_session referrals.attribution_sessions%ROWTYPE;
    v_existing referrals.referrals%ROWTYPE;
    v_decision text;
    v_reason text;
    v_referral_id uuid;
BEGIN
    IF v_referred_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF coalesce(btrim(p_referral_code), '') = '' THEN
        RAISE EXCEPTION 'Referral code is required' USING ERRCODE = '22023';
    END IF;

    SELECT id INTO v_referrer_id
      FROM users.profiles
     WHERE referral_code = btrim(p_referral_code)
       AND is_active IS TRUE
       AND account_status = 'active';
    IF v_referrer_id IS NULL THEN
        RAISE EXCEPTION 'Referral code not found' USING ERRCODE = '22023';
    END IF;

    IF p_attribution_session_id IS NOT NULL THEN
        SELECT * INTO v_session FROM referrals.attribution_sessions WHERE id = p_attribution_session_id FOR UPDATE;
        IF NOT FOUND OR v_session.referral_code <> btrim(p_referral_code) OR v_session.status <> 'pending' THEN
            RAISE EXCEPTION 'Attribution session is invalid or no longer pending' USING ERRCODE = '55000';
        END IF;
        v_method := v_session.method;
    END IF;

    SELECT * INTO v_existing FROM referrals.referrals WHERE referred_profile_id = v_referred_profile_id FOR UPDATE;
    IF FOUND THEN
        IF v_existing.referrer_profile_id = v_referrer_id THEN
            RETURN QUERY SELECT v_existing.id, v_existing.status, 'already_attributed'::text;
            RETURN;
        END IF;
        RAISE EXCEPTION 'Referred profile already belongs to another referrer' USING ERRCODE = '23505';
    END IF;

    SELECT status, reason INTO v_decision, v_reason
      FROM referrals.attribution_decision(
        v_referrer_id, v_referred_profile_id,
        referrals.normalize_phone_hash(p_phone), referrals.normalize_email_hash(p_email)
      );

    INSERT INTO referrals.referrals (
        referrer_profile_id, referred_profile_id, referral_code, attribution_method,
        attribution_session_id, status
    ) VALUES (
        v_referrer_id, v_referred_profile_id, btrim(p_referral_code), v_method,
        p_attribution_session_id, v_decision
    ) RETURNING id INTO v_referral_id;

    IF p_attribution_session_id IS NOT NULL THEN
        UPDATE referrals.attribution_sessions
           SET status = 'consumed', consumed_profile_id = v_referred_profile_id
         WHERE id = p_attribution_session_id;
    END IF;

    IF v_decision = 'review_required' THEN
        INSERT INTO referrals.review_cases (referral_id, case_type, notes)
        VALUES (v_referral_id, 'self_referral', v_reason);
    END IF;

    INSERT INTO referrals.audit_events (
        entity_type, entity_id, event_type, actor_profile_id, reason, after_state
    ) VALUES (
        'referral', v_referral_id,
        CASE WHEN v_decision = 'attributed' THEN 'referral_attributed'
             WHEN v_decision = 'review_required' THEN 'referral_review_required'
             ELSE 'referral_rejected' END,
        v_referred_profile_id, v_reason,
        jsonb_build_object('referrer_profile_id', v_referrer_id, 'status', v_decision)
    );

    RETURN QUERY SELECT v_referral_id, v_decision, v_reason;
END;
$function$;

CREATE OR REPLACE FUNCTION "referrals"."resolve_review_case"(
    p_case_id uuid,
    p_decision text,
    p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals, users, core, auth
AS $function$
DECLARE
    v_case referrals.review_cases%ROWTYPE;
    v_status text;
BEGIN
    IF p_decision NOT IN ('cleared', 'rejected') THEN
        RAISE EXCEPTION 'Review decision must be cleared or rejected' USING ERRCODE = '22023';
    END IF;
    SELECT * INTO v_case FROM referrals.review_cases WHERE id = p_case_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Review case not found' USING ERRCODE = 'P0002';
    END IF;
    IF v_case.status <> 'open' THEN
        RAISE EXCEPTION 'Review case already resolved' USING ERRCODE = '55000';
    END IF;
    UPDATE referrals.review_cases
       SET status = p_decision,
           notes = coalesce(p_notes, notes),
           resolved_at = now()
     WHERE id = p_case_id;

    v_status := CASE WHEN p_decision = 'cleared' THEN 'attributed' ELSE 'ineligible' END;
    UPDATE referrals.referrals
       SET status = v_status, updated_at = now()
     WHERE id = v_case.referral_id
       AND NOT EXISTS (SELECT 1 FROM referrals.rewards WHERE referral_id = v_case.referral_id);

    INSERT INTO referrals.audit_events (
        entity_type, entity_id, event_type, reason, after_state
    ) VALUES (
        'review_case', p_case_id, 'review_case_resolved', p_notes,
        jsonb_build_object('decision', p_decision, 'referral_status', v_status)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION "referrals"."admin_reassign_referral"(
    p_referral_id uuid,
    p_referrer_profile_id uuid,
    p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals, users, core, auth
AS $function$
DECLARE
    v_old uuid;
BEGIN
    IF coalesce(btrim(p_reason), '') = '' THEN
        RAISE EXCEPTION 'Reassignment reason is required' USING ERRCODE = '22023';
    END IF;
    IF EXISTS (SELECT 1 FROM referrals.rewards WHERE referral_id = p_referral_id) THEN
        RAISE EXCEPTION 'Cannot reassign a referral after reward creation' USING ERRCODE = '55000';
    END IF;
    SELECT referrer_profile_id INTO v_old FROM referrals.referrals WHERE id = p_referral_id FOR UPDATE;
    IF v_old IS NULL THEN
        RAISE EXCEPTION 'Referral not found' USING ERRCODE = 'P0002';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users.profiles WHERE id = p_referrer_profile_id AND is_active IS TRUE) THEN
        RAISE EXCEPTION 'New referrer profile is invalid' USING ERRCODE = '22023';
    END IF;
    UPDATE referrals.referrals
       SET referrer_profile_id = p_referrer_profile_id, updated_at = now()
     WHERE id = p_referral_id;
    INSERT INTO referrals.audit_events (
        entity_type, entity_id, event_type, reason, before_state, after_state
    ) VALUES (
        'referral', p_referral_id, 'referral_reassigned', p_reason,
        jsonb_build_object('referrer_profile_id', v_old),
        jsonb_build_object('referrer_profile_id', p_referrer_profile_id)
    );
END;
$function$;

REVOKE ALL ON FUNCTION "referrals"."normalize_phone_hash"(text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION "referrals"."normalize_email_hash"(text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION "referrals"."attribution_decision"(uuid, uuid, text, text) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION "referrals"."get_or_create_referral_code"() FROM PUBLIC, "anon";
GRANT EXECUTE ON FUNCTION "referrals"."get_or_create_referral_code"() TO "authenticated";
REVOKE ALL ON FUNCTION "referrals"."create_attribution_session"(text, text, timestamp with time zone) FROM PUBLIC, "anon";
GRANT EXECUTE ON FUNCTION "referrals"."create_attribution_session"(text, text, timestamp with time zone) TO "authenticated";
REVOKE ALL ON FUNCTION "referrals"."register_referral"(text, uuid, text, text) FROM PUBLIC, "anon";
GRANT EXECUTE ON FUNCTION "referrals"."register_referral"(text, uuid, text, text) TO "authenticated";
REVOKE ALL ON FUNCTION "referrals"."resolve_review_case"(uuid, text, text) FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "referrals"."resolve_review_case"(uuid, text, text) TO "service_role";
REVOKE ALL ON FUNCTION "referrals"."admin_reassign_referral"(uuid, uuid, text) FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "referrals"."admin_reassign_referral"(uuid, uuid, text) TO "service_role";

COMMIT;
