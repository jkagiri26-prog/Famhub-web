-- ============================================================================
-- 20261113000004_referrals_recovery_workflow
-- ----------------------------------------------------------------------------
-- Forward-only manual recovery workflow for already-paid referral rewards.
-- No automatic clawback or offset against unrelated rewards.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION "referrals"."record_recovery"(
    p_reward_id uuid,
    p_reason text,
    p_idempotency_key text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals, finance, core, users
AS $function$
DECLARE
    v_reward referrals.rewards%ROWTYPE;
    v_platform uuid;
    v_entity uuid;
    v_key text := nullif(btrim(p_idempotency_key), '');
    v_obligation_id uuid;
BEGIN
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
        reward_id, event_type, amount, from_status, to_status, metadata
    ) VALUES (
        v_reward.id, 'recovery_created', v_reward.amount, 'paid', 'paid',
        jsonb_build_object('recovery_obligation_id', v_obligation_id, 'reason', p_reason)
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, reason, after_state)
    VALUES ('reward', v_reward.id, 'recovery_created', p_reason,
            jsonb_build_object('recovery_obligation_id', v_obligation_id, 'withdrawal_blocked', true));
    RETURN v_obligation_id;
END;
$function$;

CREATE OR REPLACE FUNCTION "referrals"."resolve_recovery"(
    p_reward_id uuid,
    p_decision text,
    p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals
AS $function$
DECLARE
    v_reward referrals.rewards%ROWTYPE;
BEGIN
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
        reward_id, event_type, from_status, to_status, metadata
    ) VALUES (
        p_reward_id, 'recovery_' || p_decision, v_reward.status, v_reward.status,
        jsonb_build_object('recovery_obligation_id', v_reward.recovery_obligation_id, 'notes', p_notes)
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, reason, after_state)
    VALUES ('reward', p_reward_id, 'recovery_' || p_decision, p_notes,
            jsonb_build_object('withdrawal_blocked', p_decision <> 'cleared'));
END;
$function$;

REVOKE ALL ON FUNCTION "referrals"."record_recovery"(uuid, text, text) FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "referrals"."record_recovery"(uuid, text, text) TO "service_role";
REVOKE ALL ON FUNCTION "referrals"."resolve_recovery"(uuid, text, text) FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "referrals"."resolve_recovery"(uuid, text, text) TO "service_role";

COMMIT;
