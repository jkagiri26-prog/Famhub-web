-- ============================================================================
-- 20261114000005_referrals_platform_admin_authority
-- ----------------------------------------------------------------------------
-- Phase 1 Refer & Earn hardening:
--   * explicit platform-admin authority
--   * trusted actor derivation/validation
--   * actor attribution for existing administrative actions
--
-- This migration does not change qualification, subscription, ledger,
-- withdrawal-amount, worker, reversal, or entity-provisioning behavior.
-- ============================================================================

BEGIN;

-- Reuse the existing production administration role. Do not create a
-- duplicate platform_admin role, and do not treat the Super Admin role as
-- automatically equivalent until its permissions/scopes are explicitly
-- aligned and approved.
CREATE OR REPLACE FUNCTION core.is_platform_admin(p_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'core', 'users'
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM users.profiles AS p
      JOIN core.entity_roles AS er
        ON er.profile_id = p.id
       AND er.is_active IS TRUE
      JOIN core.entities AS e
        ON e.id = er.entity_id
       AND e.is_active IS TRUE
       AND e.metadata->>'platform_entity' = 'true'
       AND e.metadata->>'purpose' = 'platform_administration'
      JOIN core.user_roles AS r
        ON r.id = er.role_id
       AND r.is_active IS TRUE
       AND r.name = 'Admin'
      JOIN core.entity_members AS em
        ON em.entity_id = e.id
       AND em.profile_id = p.id
       AND em.role_id = r.id
       AND em.is_active IS TRUE
       AND em.membership_status = 'active'
     WHERE p.id = p_profile_id
       AND p.is_active IS TRUE
       AND p.account_status = 'active'
  );
$function$;

ALTER FUNCTION core.is_platform_admin(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION core.is_platform_admin(uuid) FROM PUBLIC, "anon", "authenticated", "service_role";

CREATE OR REPLACE FUNCTION referrals.resolve_admin_actor(p_actor_profile_id uuid DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals', 'core', 'users', 'auth'
AS $function$
DECLARE
    v_auth_uid uuid := auth.uid();
    v_context_profile uuid;
    v_auth_role text := auth.role();
    v_actor uuid;
BEGIN
    IF v_auth_uid IS NOT NULL THEN
        v_context_profile := core.current_profile_id();
        IF v_context_profile IS NULL THEN
            RAISE EXCEPTION 'Authenticated profile is required' USING ERRCODE = '42501';
        END IF;
        IF p_actor_profile_id IS NOT NULL AND p_actor_profile_id <> v_context_profile THEN
            RAISE EXCEPTION 'Supplied actor does not match authenticated profile' USING ERRCODE = '42501';
        END IF;
        v_actor := v_context_profile;
    ELSE
        IF coalesce(v_auth_role, '') <> 'service_role' THEN
            RAISE EXCEPTION 'A trusted service role is required to supply an actor' USING ERRCODE = '42501';
        END IF;
        IF p_actor_profile_id IS NULL THEN
            RAISE EXCEPTION 'An actor profile is required for service-role execution' USING ERRCODE = '42501';
        END IF;
        v_actor := p_actor_profile_id;
    END IF;

    IF NOT core.is_platform_admin(v_actor) THEN
        RAISE EXCEPTION 'Actor is not an active platform admin' USING ERRCODE = '42501';
    END IF;

    RETURN v_actor;
END;
$function$;

ALTER FUNCTION referrals.resolve_admin_actor(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION referrals.resolve_admin_actor(uuid) FROM PUBLIC, "anon", "authenticated", "service_role";

DROP FUNCTION IF EXISTS referrals.approve_withdrawal(uuid, uuid, text);
CREATE OR REPLACE FUNCTION referrals.approve_withdrawal(
    p_request_id uuid,
    p_recipient_entity_id uuid,
    p_notes text DEFAULT NULL,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals', 'finance', 'core', 'users'
AS $function$
DECLARE
    v_request referrals.withdrawal_requests%ROWTYPE;
    v_platform uuid;
    v_obligation_id uuid;
    v_actor uuid;
BEGIN
    v_actor := referrals.resolve_admin_actor(p_actor_profile_id);

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
           reviewed_by = v_actor, reviewed_at = now(), approved_at = now(),
           decision_notes = p_notes, version = version + 1, updated_at = now()
     WHERE id = v_request.id;

    INSERT INTO referrals.withdrawal_events (
        withdrawal_request_id, event_type, actor_profile_id, from_status, to_status, amount, notes
    ) VALUES (
        v_request.id, 'withdrawal_approved', v_actor, 'requested', 'approved', v_request.amount, p_notes
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, actor_profile_id, reason, after_state)
    VALUES ('withdrawal', v_request.id, 'withdrawal_approved', v_actor, p_notes,
            jsonb_build_object('finance_obligation_id', v_obligation_id, 'recipient_entity_id', p_recipient_entity_id));
    RETURN v_obligation_id;
END;
$function$;

DROP FUNCTION IF EXISTS referrals.reject_withdrawal(uuid, text);
CREATE OR REPLACE FUNCTION referrals.reject_withdrawal(
    p_request_id uuid,
    p_notes text DEFAULT NULL,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals'
AS $function$
DECLARE
    v_request referrals.withdrawal_requests%ROWTYPE;
    v_actor uuid;
BEGIN
    v_actor := referrals.resolve_admin_actor(p_actor_profile_id);

    SELECT * INTO v_request FROM referrals.withdrawal_requests WHERE id = p_request_id FOR UPDATE;
    IF NOT FOUND OR v_request.status <> 'requested' THEN
        RAISE EXCEPTION 'Withdrawal request is not pending rejection' USING ERRCODE = '55000';
    END IF;
    UPDATE referrals.withdrawal_requests
       SET status = 'rejected', reviewed_by = v_actor, reviewed_at = now(),
           decision_notes = p_notes, version = version + 1, updated_at = now()
     WHERE id = v_request.id;
    INSERT INTO referrals.withdrawal_events (
        withdrawal_request_id, event_type, actor_profile_id, from_status, to_status, amount, notes
    ) VALUES (
        v_request.id, 'withdrawal_rejected', v_actor, 'requested', 'rejected', v_request.amount, p_notes
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, actor_profile_id, reason)
    VALUES ('withdrawal', v_request.id, 'withdrawal_rejected', v_actor, p_notes);
END;
$function$;

DROP FUNCTION IF EXISTS referrals.resolve_review_case(uuid, text, text);
CREATE OR REPLACE FUNCTION referrals.resolve_review_case(
    p_case_id uuid,
    p_decision text,
    p_notes text DEFAULT NULL,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals', 'users', 'core', 'auth'
AS $function$
DECLARE
    v_case referrals.review_cases%ROWTYPE;
    v_status text;
    v_actor uuid;
BEGIN
    v_actor := referrals.resolve_admin_actor(p_actor_profile_id);

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
           resolved_by = v_actor,
           resolved_at = now()
     WHERE id = p_case_id;

    v_status := CASE WHEN p_decision = 'cleared' THEN 'attributed' ELSE 'ineligible' END;
    UPDATE referrals.referrals
       SET status = v_status, updated_at = now()
     WHERE id = v_case.referral_id
       AND NOT EXISTS (SELECT 1 FROM referrals.rewards WHERE referral_id = v_case.referral_id);

    INSERT INTO referrals.audit_events (
        entity_type, entity_id, event_type, actor_profile_id, reason, after_state
    ) VALUES (
        'review_case', p_case_id, 'review_case_resolved', v_actor, p_notes,
        jsonb_build_object('decision', p_decision, 'referral_status', v_status)
    );
END;
$function$;

DROP FUNCTION IF EXISTS referrals.admin_reassign_referral(uuid, uuid, text);
CREATE OR REPLACE FUNCTION referrals.admin_reassign_referral(
    p_referral_id uuid,
    p_referrer_profile_id uuid,
    p_reason text,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals', 'users', 'core', 'auth'
AS $function$
DECLARE
    v_old uuid;
    v_actor uuid;
BEGIN
    v_actor := referrals.resolve_admin_actor(p_actor_profile_id);

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
        entity_type, entity_id, event_type, actor_profile_id, reason, before_state, after_state
    ) VALUES (
        'referral', p_referral_id, 'referral_reassigned', v_actor, p_reason,
        jsonb_build_object('referrer_profile_id', v_old),
        jsonb_build_object('referrer_profile_id', p_referrer_profile_id)
    );
END;
$function$;

DROP FUNCTION IF EXISTS referrals.record_manual_payout(uuid, text, jsonb, timestamp with time zone);
CREATE OR REPLACE FUNCTION referrals.record_manual_payout(
    p_request_id uuid,
    p_mpesa_receipt text,
    p_payout_evidence jsonb,
    p_paid_at timestamp with time zone DEFAULT now(),
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals', 'finance', 'core'
AS $function$
DECLARE
    v_request referrals.withdrawal_requests%ROWTYPE;
    v_obligation finance.obligations%ROWTYPE;
    v_payment finance.payments%ROWTYPE;
    v_settlement finance.obligation_settlements%ROWTYPE;
    v_mapping finance.referral_account_settings%ROWTYPE;
    v_cash_account uuid;
    v_payment_id uuid;
    v_journal_id uuid;
    v_settlement_id uuid;
    v_receipt text := nullif(btrim(p_mpesa_receipt), '');
    v_actor uuid;
BEGIN
    v_actor := referrals.resolve_admin_actor(p_actor_profile_id);

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
    IF v_request.finance_obligation_id IS NULL OR v_request.recipient_entity_id IS NULL THEN
        RAISE EXCEPTION 'Withdrawal has no linked payout obligation or recipient' USING ERRCODE = '55000';
    END IF;

    SELECT * INTO STRICT v_obligation FROM finance.obligations WHERE id = v_request.finance_obligation_id FOR UPDATE;
    IF v_obligation.status <> 'settled'
       AND v_obligation.status <> 'open'
       AND v_obligation.status <> 'partially_settled' THEN
        RAISE EXCEPTION 'Payout obligation is not payable' USING ERRCODE = '55000';
    END IF;
    IF v_obligation.amount <> v_request.amount OR v_obligation.currency <> 'KES' THEN
        RAISE EXCEPTION 'Payout obligation amount or currency does not match the withdrawal' USING ERRCODE = '23514';
    END IF;
    IF v_obligation.payer_entity_id IS NULL
       OR v_obligation.payee_entity_id IS DISTINCT FROM v_request.recipient_entity_id THEN
        RAISE EXCEPTION 'Payout obligation parties do not match the withdrawal recipient' USING ERRCODE = '23514';
    END IF;

    SELECT * INTO v_mapping
      FROM finance.referral_account_settings
     WHERE platform_entity_id = v_obligation.payer_entity_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Referral account mapping is missing for the platform entity' USING ERRCODE = '55000';
    END IF;
    SELECT id INTO v_cash_account
      FROM finance.ledger_accounts
     WHERE entity_id = v_obligation.payer_entity_id
       AND account_code = '1000'
       AND account_type = 'asset'
       AND normal_balance = 'debit'
       AND currency = 'KES'
       AND is_active IS TRUE;
    IF v_cash_account IS NULL THEN
        RAISE EXCEPTION 'Platform KES clearing account 1000 is missing or invalid' USING ERRCODE = '55000';
    END IF;

    SELECT * INTO v_payment
      FROM finance.payments
     WHERE obligation_id = v_obligation.id
       AND provider = 'manual_mpesa'
       AND provider_reference = v_receipt
     FOR UPDATE;
    IF FOUND THEN
        RAISE EXCEPTION 'Payout receipt has already been recorded' USING ERRCODE = '23505';
    END IF;

    INSERT INTO finance.payments (
        obligation_id, payer_entity_id, payee_entity_id, provider, provider_reference,
        amount, currency, verified_at, verification_metadata
    ) VALUES (
        v_obligation.id, v_obligation.payer_entity_id, v_obligation.payee_entity_id,
        'manual_mpesa', v_receipt, v_request.amount, 'KES', p_paid_at,
        jsonb_build_object('withdrawal_request_id', v_request.id, 'manual_payout', true, 'evidence', p_payout_evidence)
    ) RETURNING * INTO v_payment;

    INSERT INTO finance.journals (
        entity_id, journal_date, currency, status, description, source_type, source_id, idempotency_key
    ) VALUES (
        v_obligation.payer_entity_id, p_paid_at::date, 'KES', 'draft',
        'Manual M-Pesa referral payout ' || v_request.id::text,
        'payment', v_payment.id, 'referral-payout-journal:' || v_request.id::text
    ) RETURNING id INTO v_journal_id;

    INSERT INTO finance.journal_lines (
        journal_id, entity_id, currency, line_number, account_id,
        debit_amount, credit_amount, description
    ) VALUES
      (v_journal_id, v_obligation.payer_entity_id, 'KES', 1, v_mapping.payable_account_id,
       v_request.amount, 0, 'Reduce referral rewards payable'),
      (v_journal_id, v_obligation.payer_entity_id, 'KES', 2, v_cash_account,
       0, v_request.amount, 'Manual M-Pesa payout');

    PERFORM finance.post_journal(v_journal_id);

    INSERT INTO finance.obligation_settlements (
        obligation_id, payment_id, currency, amount, settled_at, idempotency_key,
        journal_id, metadata
    ) VALUES (
        v_obligation.id, v_payment.id, 'KES', v_request.amount, p_paid_at,
        'referral-payout:' || v_request.id::text, v_journal_id,
        jsonb_build_object('withdrawal_request_id', v_request.id, 'manual_mpesa_receipt', v_receipt)
    ) RETURNING * INTO v_settlement;

    UPDATE finance.obligations
       SET status = 'settled', updated_at = clock_timestamp()
     WHERE id = v_obligation.id;

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
        withdrawal_request_id, event_type, actor_profile_id, from_status, to_status, amount,
        mpesa_receipt, evidence
    ) VALUES (
        v_request.id, 'withdrawal_paid', v_actor, 'approved', 'paid', v_request.amount,
        v_receipt, p_payout_evidence
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, actor_profile_id, after_state)
    VALUES ('withdrawal', v_request.id, 'withdrawal_paid', v_actor,
            jsonb_build_object('mpesa_receipt', v_receipt, 'amount', v_request.amount,
                               'payment_id', v_payment.id, 'settlement_id', v_settlement.id,
                               'journal_id', v_journal_id));
END;
$function$;

DROP FUNCTION IF EXISTS referrals.record_recovery(uuid, text, text);
CREATE OR REPLACE FUNCTION referrals.record_recovery(
    p_reward_id uuid,
    p_reason text,
    p_idempotency_key text,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals', 'finance', 'core', 'users'
AS $function$
DECLARE
    v_reward referrals.rewards%ROWTYPE;
    v_platform uuid;
    v_entity uuid;
    v_key text := nullif(btrim(p_idempotency_key), '');
    v_obligation_id uuid;
    v_actor uuid;
BEGIN
    v_actor := referrals.resolve_admin_actor(p_actor_profile_id);

    IF coalesce(btrim(p_reason), '') = '' OR v_key IS NULL THEN
        RAISE EXCEPTION 'A recovery reason and idempotency key are required' USING ERRCODE = '22023';
    END IF;
    SELECT * INTO v_reward FROM referrals.rewards WHERE id = p_reward_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reward not found' USING ERRCODE = 'P0002';
    END IF;
    IF v_reward.status <> 'paid' THEN
        RAISE EXCEPTION 'Only an already-paid reward can enter recovery' USING ERRCODE = '55000';
    END IF;
    IF v_reward.recovery_obligation_id IS NOT NULL THEN
        RETURN v_reward.recovery_obligation_id;
    END IF;

    SELECT id INTO v_platform FROM core.entities
     WHERE is_active IS TRUE AND metadata->>'platform_entity' = 'true'
       AND metadata->>'purpose' = 'platform_administration';
    SELECT id INTO v_entity FROM core.entities
     WHERE owner_id = v_reward.beneficiary_profile_id
       AND entity_type = 'individual_pro'
       AND is_active IS TRUE
     ORDER BY created_at, id LIMIT 1;
    IF v_platform IS NULL OR v_entity IS NULL THEN
        RAISE EXCEPTION 'Platform or beneficiary entity missing for recovery' USING ERRCODE = '55000';
    END IF;

    v_obligation_id := finance.create_obligation(
        v_entity, v_platform, v_reward.amount, v_reward.currency,
        v_key, 'other', NULL, NULL, NULL,
        'Referral reward recovery ' || p_reward_id::text,
        jsonb_build_object('finance_charge_code', 'referral_recovery', 'reward_id', p_reward_id, 'reason', p_reason)
    );

    UPDATE referrals.rewards
       SET recovery_obligation_id = v_obligation_id,
           withdrawal_blocked = true, updated_at = now()
     WHERE id = v_reward.id;

    INSERT INTO referrals.reward_events (
        reward_id, event_type, actor_profile_id, amount, from_status, to_status, metadata
    ) VALUES (
        v_reward.id, 'recovery_created', v_actor, v_reward.amount, 'paid', 'paid',
        jsonb_build_object('recovery_obligation_id', v_obligation_id, 'reason', p_reason)
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, actor_profile_id, reason, after_state)
    VALUES ('reward', v_reward.id, 'recovery_created', v_actor, p_reason,
            jsonb_build_object('recovery_obligation_id', v_obligation_id, 'withdrawal_blocked', true));
    RETURN v_obligation_id;
END;
$function$;

DROP FUNCTION IF EXISTS referrals.resolve_recovery(uuid, text, text);
CREATE OR REPLACE FUNCTION referrals.resolve_recovery(
    p_reward_id uuid,
    p_decision text,
    p_notes text DEFAULT NULL,
    p_actor_profile_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'referrals'
AS $function$
DECLARE
    v_reward referrals.rewards%ROWTYPE;
    v_actor uuid;
BEGIN
    v_actor := referrals.resolve_admin_actor(p_actor_profile_id);

    IF p_decision NOT IN ('cleared', 'rejected') THEN
        RAISE EXCEPTION 'Recovery decision must be cleared or rejected' USING ERRCODE = '22023';
    END IF;
    SELECT * INTO v_reward FROM referrals.rewards WHERE id = p_reward_id FOR UPDATE;
    IF NOT FOUND OR v_reward.recovery_obligation_id IS NULL THEN
        RAISE EXCEPTION 'Recovery case not found' USING ERRCODE = 'P0002';
    END IF;
    UPDATE referrals.rewards
       SET withdrawal_blocked = CASE WHEN p_decision = 'cleared' THEN false ELSE true END,
           updated_at = now()
     WHERE id = p_reward_id;
    INSERT INTO referrals.reward_events (
        reward_id, event_type, actor_profile_id, from_status, to_status, metadata
    ) VALUES (
        p_reward_id, 'recovery_' || p_decision, v_actor, v_reward.status, v_reward.status,
        jsonb_build_object('recovery_obligation_id', v_reward.recovery_obligation_id, 'notes', p_notes)
    );
    INSERT INTO referrals.audit_events (entity_id, entity_type, event_type, actor_profile_id, reason, after_state)
    VALUES (p_reward_id, 'reward', 'recovery_' || p_decision, v_actor, p_notes,
            jsonb_build_object('withdrawal_blocked', p_decision <> 'cleared'));
END;
$function$;

ALTER FUNCTION referrals.approve_withdrawal(uuid, uuid, text, uuid) OWNER TO postgres;
ALTER FUNCTION referrals.reject_withdrawal(uuid, text, uuid) OWNER TO postgres;
ALTER FUNCTION referrals.resolve_review_case(uuid, text, text, uuid) OWNER TO postgres;
ALTER FUNCTION referrals.admin_reassign_referral(uuid, uuid, text, uuid) OWNER TO postgres;
ALTER FUNCTION referrals.record_manual_payout(uuid, text, jsonb, timestamp with time zone, uuid) OWNER TO postgres;
ALTER FUNCTION referrals.record_recovery(uuid, text, text, uuid) OWNER TO postgres;
ALTER FUNCTION referrals.resolve_recovery(uuid, text, text, uuid) OWNER TO postgres;

REVOKE ALL ON FUNCTION referrals.approve_withdrawal(uuid, uuid, text, uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION referrals.reject_withdrawal(uuid, text, uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION referrals.resolve_review_case(uuid, text, text, uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION referrals.admin_reassign_referral(uuid, uuid, text, uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION referrals.record_manual_payout(uuid, text, jsonb, timestamp with time zone, uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION referrals.record_recovery(uuid, text, text, uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
REVOKE ALL ON FUNCTION referrals.resolve_recovery(uuid, text, text, uuid) FROM PUBLIC, "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION referrals.approve_withdrawal(uuid, uuid, text, uuid) TO "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION referrals.reject_withdrawal(uuid, text, uuid) TO "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION referrals.resolve_review_case(uuid, text, text, uuid) TO "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION referrals.admin_reassign_referral(uuid, uuid, text, uuid) TO "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION referrals.record_manual_payout(uuid, text, jsonb, timestamp with time zone, uuid) TO "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION referrals.record_recovery(uuid, text, text, uuid) TO "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION referrals.resolve_recovery(uuid, text, text, uuid) TO "authenticated", "service_role";

COMMIT;
