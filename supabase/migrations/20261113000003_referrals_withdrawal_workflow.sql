-- ============================================================================
-- 20261113000003_referrals_withdrawal_workflow
-- ----------------------------------------------------------------------------
-- Forward-only manual M-Pesa Refer & Earn withdrawal lifecycle.
-- ============================================================================

BEGIN;

ALTER TABLE "referrals"."rewards"
    ADD COLUMN IF NOT EXISTS "withdrawal_blocked" boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION "referrals"."get_reward_balance"()
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, referrals, core, auth
AS $function$
DECLARE
    v_profile_id uuid := core.current_profile_id();
    v_balance numeric(20,4);
BEGIN
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    SELECT coalesce(sum(r.amount), 0) INTO v_balance
      FROM referrals.rewards r
     WHERE r.beneficiary_profile_id = v_profile_id
       AND r.status = 'eligible'
       AND r.withdrawal_request_id IS NULL
       AND r.withdrawal_blocked IS FALSE;
    RETURN v_balance;
END;
$function$;

CREATE OR REPLACE FUNCTION "referrals"."request_withdrawal"(
    p_amount numeric,
    p_idempotency_key text
)
RETURNS TABLE(withdrawal_request_id uuid, status text, amount numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals, core, auth
AS $function$
DECLARE
    v_profile_id uuid := core.current_profile_id();
    v_existing referrals.withdrawal_requests%ROWTYPE;
    v_request_id uuid;
    v_balance numeric(20,4);
    v_reward referrals.rewards%ROWTYPE;
    v_key text := nullif(btrim(p_idempotency_key), '');
BEGIN
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF v_key IS NULL THEN
        RAISE EXCEPTION 'An idempotency key is required' USING ERRCODE = '22023';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended('referral-withdrawal:' || v_profile_id::text, 0));

    SELECT * INTO v_existing FROM referrals.withdrawal_requests WHERE idempotency_key = v_key;
    IF FOUND THEN
        IF v_existing.beneficiary_profile_id = v_profile_id AND v_existing.amount = p_amount THEN
            RETURN QUERY SELECT v_existing.id, v_existing.status, v_existing.amount;
            RETURN;
        END IF;
        RAISE EXCEPTION 'Idempotency key was used with different withdrawal data' USING ERRCODE = '23505';
    END IF;

    IF EXISTS (SELECT 1 FROM referrals.withdrawal_requests wr WHERE wr.beneficiary_profile_id = v_profile_id AND wr.status IN ('requested','approved','uncertain')) THEN
        RAISE EXCEPTION 'An open withdrawal already exists for this beneficiary' USING ERRCODE = '55000';
    END IF;

    SELECT coalesce(sum(r.amount), 0) INTO v_balance
      FROM referrals.rewards r
     WHERE r.beneficiary_profile_id = v_profile_id
       AND r.status = 'eligible'
       AND r.withdrawal_request_id IS NULL
       AND r.withdrawal_blocked IS FALSE;

    IF p_amount IS NULL OR p_amount < 500 THEN
        RAISE EXCEPTION 'Minimum withdrawal is KSh 500' USING ERRCODE = '22023';
    END IF;
    IF p_amount > v_balance THEN
        RAISE EXCEPTION 'Withdrawal exceeds eligible reward balance' USING ERRCODE = '22023';
    END IF;
    IF p_amount <> v_balance THEN
        RAISE EXCEPTION 'The entire eligible reward balance must be withdrawn' USING ERRCODE = '22023';
    END IF;

    INSERT INTO referrals.withdrawal_requests (
        beneficiary_profile_id, amount, currency, status, idempotency_key, version
    ) VALUES (
        v_profile_id, p_amount, 'KES', 'requested', v_key, 1
    ) RETURNING id INTO v_request_id;

    FOR v_reward IN
        SELECT r.* FROM referrals.rewards r
         WHERE r.beneficiary_profile_id = v_profile_id
           AND r.status = 'eligible'
           AND r.withdrawal_request_id IS NULL
           AND r.withdrawal_blocked IS FALSE
         ORDER BY r.created_at, r.id
         FOR UPDATE
    LOOP
        INSERT INTO referrals.withdrawal_items (
            withdrawal_request_id, reward_id, amount, status
        ) VALUES (
            v_request_id, v_reward.id, v_reward.amount, 'reserved'
        );
        UPDATE referrals.rewards
           SET status = 'locked', withdrawal_request_id = v_request_id, updated_at = now()
         WHERE id = v_reward.id;
    END LOOP;

    INSERT INTO referrals.withdrawal_events (
        withdrawal_request_id, event_type, actor_profile_id, from_status, to_status, amount
    ) VALUES (
        v_request_id, 'withdrawal_requested', v_profile_id, NULL, 'requested', p_amount
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, actor_profile_id, after_state)
    VALUES ('withdrawal', v_request_id, 'withdrawal_requested', v_profile_id,
            jsonb_build_object('amount', p_amount, 'currency', 'KES'));

    RETURN QUERY SELECT v_request_id, 'requested'::text, p_amount;
END;
$function$;

CREATE OR REPLACE FUNCTION "referrals"."approve_withdrawal"(
    p_request_id uuid,
    p_recipient_entity_id uuid,
    p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals, finance, core, users
AS $function$
DECLARE
    v_request referrals.withdrawal_requests%ROWTYPE;
    v_platform uuid;
    v_obligation_id uuid;
BEGIN
    SELECT * INTO v_request FROM referrals.withdrawal_requests WHERE id = p_request_id FOR UPDATE;
    IF NOT FOUND OR v_request.status <> 'requested' THEN
        RAISE EXCEPTION 'Withdrawal request is not pending approval' USING ERRCODE = '55000';
    END IF;
    IF p_recipient_entity_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM core.entities
         WHERE id = p_recipient_entity_id
           AND owner_id = v_request.beneficiary_profile_id
           AND is_active IS TRUE
    ) THEN
        RAISE EXCEPTION 'Recipient entity must belong to the beneficiary' USING ERRCODE = '42501';
    END IF;
    SELECT id INTO v_platform FROM core.entities
     WHERE is_active IS TRUE AND metadata->>'platform_entity' = 'true'
       AND metadata->>'purpose' = 'platform_administration';
    IF v_platform IS NULL THEN
        RAISE EXCEPTION 'Platform administration entity missing' USING ERRCODE = '55000';
    END IF;

    v_obligation_id := finance.create_obligation(
        v_platform, p_recipient_entity_id, v_request.amount, 'KES',
        'referral-withdrawal:' || v_request.id::text, 'other',
        NULL, NULL, NULL, 'Manual M-Pesa referral withdrawal ' || v_request.id::text,
        jsonb_build_object('finance_charge_code', 'referral_withdrawal', 'withdrawal_request_id', v_request.id)
    );

    UPDATE referrals.withdrawal_requests
       SET status = 'approved', finance_obligation_id = v_obligation_id,
           recipient_entity_id = p_recipient_entity_id, recipient_verified_at = now(),
           reviewed_at = now(), approved_at = now(), decision_notes = p_notes,
           version = version + 1, updated_at = now()
     WHERE id = v_request.id;

    INSERT INTO referrals.withdrawal_events (
        withdrawal_request_id, event_type, from_status, to_status, amount, notes
    ) VALUES (
        v_request.id, 'withdrawal_approved', 'requested', 'approved', v_request.amount, p_notes
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, reason, after_state)
    VALUES ('withdrawal', v_request.id, 'withdrawal_approved', p_notes,
            jsonb_build_object('finance_obligation_id', v_obligation_id, 'recipient_entity_id', p_recipient_entity_id));
    RETURN v_obligation_id;
END;
$function$;

CREATE OR REPLACE FUNCTION "referrals"."reject_withdrawal"(
    p_request_id uuid,
    p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals
AS $function$
DECLARE
    v_request referrals.withdrawal_requests%ROWTYPE;
BEGIN
    SELECT * INTO v_request FROM referrals.withdrawal_requests WHERE id = p_request_id FOR UPDATE;
    IF NOT FOUND OR v_request.status <> 'requested' THEN
        RAISE EXCEPTION 'Withdrawal request is not pending rejection' USING ERRCODE = '55000';
    END IF;
    UPDATE referrals.withdrawal_requests
       SET status = 'rejected', reviewed_at = now(), decision_notes = p_notes,
           version = version + 1, updated_at = now()
     WHERE id = v_request.id;
    INSERT INTO referrals.withdrawal_events (
        withdrawal_request_id, event_type, from_status, to_status, amount, notes
    ) VALUES (
        v_request.id, 'withdrawal_rejected', 'requested', 'rejected', v_request.amount, p_notes
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, reason)
    VALUES ('withdrawal', v_request.id, 'withdrawal_rejected', p_notes);
END;
$function$;

CREATE OR REPLACE FUNCTION "referrals"."record_manual_payout"(
    p_request_id uuid,
    p_mpesa_receipt text,
    p_payout_evidence jsonb,
    p_paid_at timestamp with time zone DEFAULT now()
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals
AS $function$
DECLARE
    v_request referrals.withdrawal_requests%ROWTYPE;
    v_receipt text := nullif(btrim(p_mpesa_receipt), '');
BEGIN
    IF v_receipt IS NULL OR p_payout_evidence IS NULL OR jsonb_typeof(p_payout_evidence) <> 'object' THEN
        RAISE EXCEPTION 'A valid M-Pesa receipt and payout evidence object are required' USING ERRCODE = '22023';
    END IF;
    SELECT * INTO v_request FROM referrals.withdrawal_requests WHERE id = p_request_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Withdrawal request not found' USING ERRCODE = 'P0002';
    END IF;
    IF v_request.status = 'paid' THEN
        IF v_request.mpesa_receipt = v_receipt THEN
            RETURN;
        END IF;
        RAISE EXCEPTION 'Withdrawal is already paid with different evidence' USING ERRCODE = '23505';
    END IF;
    IF v_request.status <> 'approved' THEN
        RAISE EXCEPTION 'Only approved withdrawals can be paid' USING ERRCODE = '55000';
    END IF;

    UPDATE referrals.withdrawal_requests
       SET status = 'paid', paid_at = p_paid_at, mpesa_receipt = v_receipt,
           payout_evidence = p_payout_evidence, version = version + 1, updated_at = now()
     WHERE id = v_request.id;

    UPDATE referrals.withdrawal_items
       SET status = 'paid'
     WHERE withdrawal_request_id = v_request.id AND status = 'reserved';

    UPDATE referrals.rewards
       SET status = 'paid', paid_at = p_paid_at, updated_at = now()
     WHERE withdrawal_request_id = v_request.id AND status = 'locked';

    INSERT INTO referrals.withdrawal_events (
        withdrawal_request_id, event_type, from_status, to_status, amount,
        mpesa_receipt, evidence
    ) VALUES (
        v_request.id, 'withdrawal_paid', 'approved', 'paid', v_request.amount,
        v_receipt, p_payout_evidence
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, after_state)
    VALUES ('withdrawal', v_request.id, 'withdrawal_paid',
            jsonb_build_object('mpesa_receipt', v_receipt, 'amount', v_request.amount));
END;
$function$;

REVOKE ALL ON FUNCTION "referrals"."get_reward_balance"() FROM PUBLIC, "anon";
GRANT EXECUTE ON FUNCTION "referrals"."get_reward_balance"() TO "authenticated";
REVOKE ALL ON FUNCTION "referrals"."request_withdrawal"(numeric, text) FROM PUBLIC, "anon";
GRANT EXECUTE ON FUNCTION "referrals"."request_withdrawal"(numeric, text) TO "authenticated";
REVOKE ALL ON FUNCTION "referrals"."approve_withdrawal"(uuid, uuid, text) FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "referrals"."approve_withdrawal"(uuid, uuid, text) TO "service_role";
REVOKE ALL ON FUNCTION "referrals"."reject_withdrawal"(uuid, text) FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "referrals"."reject_withdrawal"(uuid, text) TO "service_role";
REVOKE ALL ON FUNCTION "referrals"."record_manual_payout"(uuid, text, jsonb, timestamp with time zone) FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "referrals"."record_manual_payout"(uuid, text, jsonb, timestamp with time zone) TO "service_role";

COMMIT;
