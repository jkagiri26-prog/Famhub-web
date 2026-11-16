-- ============================================================================
-- ALREADY APPLIED — repository migration body restored from deployed audited state
-- 20261114000008_fix_referrals_consumer_failure_ambiguity
-- ----------------------------------------------------------------------------
-- Forward-only replacement for the existing private consumer, fixing the
-- ambiguity in the failure handler's ON CONFLICT target. The original
-- migration is not modified.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION referrals.consume_finance_event_core(p_event_id uuid)
 RETURNS TABLE(finance_event_id uuid, outcome text, reward_id uuid, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'referrals', 'finance', 'system', 'core', 'users', 'auth'
AS $function$
DECLARE
    v_event finance.events%ROWTYPE;
    v_consumption referrals.event_consumptions%ROWTYPE;
    v_cycle finance.subscription_cycles%ROWTYPE;
    v_obligation finance.obligations%ROWTYPE;
    v_invoice system.invoices%ROWTYPE;
    v_billing system.billing_accounts%ROWTYPE;
    v_plan system.subscription_plans%ROWTYPE;
    v_settlement finance.obligation_settlements%ROWTYPE;
    v_payment finance.payments%ROWTYPE;
    v_attempt_status text;
    v_referral referrals.referrals%ROWTYPE;
    v_reward referrals.rewards%ROWTYPE;
    v_settings referrals.program_settings%ROWTYPE;
    v_mapping finance.referral_account_settings%ROWTYPE;
    v_decision text;
    v_reason text;
    v_settled_at timestamp with time zone;
    v_settled_sum numeric(20,4);
    v_phone_hash text;
    v_email_hash text;
    v_reward_id uuid;
    v_journal_id uuid;
    v_existing_reward uuid;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended('referral-finance-event:' || p_event_id::text, 0));

    SELECT * INTO v_event FROM finance.events WHERE id = p_event_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Finance event not found' USING ERRCODE = 'P0002';
    END IF;

    SELECT * INTO v_consumption
      FROM referrals.event_consumptions ec
     WHERE ec.finance_event_id = p_event_id
     FOR UPDATE;

    IF FOUND AND v_consumption.status = 'processed' THEN
        SELECT id INTO v_existing_reward FROM referrals.rewards WHERE source_finance_event_id = p_event_id;
        RETURN QUERY SELECT p_event_id, 'already_processed'::text, v_existing_reward, NULL::text;
        RETURN;
    END IF;

    IF FOUND THEN
        UPDATE referrals.event_consumptions
           SET status = 'processing', attempts = attempts + 1, updated_at = now()
         WHERE id = v_consumption.id
         RETURNING * INTO v_consumption;
    ELSE
        INSERT INTO referrals.event_consumptions (
            finance_event_id, event_type, status, attempts
        ) VALUES (
            p_event_id, v_event.event_type, 'processing', 1
        ) RETURNING * INTO v_consumption;
    END IF;

    BEGIN
        IF v_event.event_type <> 'finance.subscription.annual.activated'
           OR v_event.source_type <> 'finance.subscription_cycle' THEN
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'unsupported_event_type', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'unsupported_event_type'::text, NULL::uuid, NULL::text;
            RETURN;
        END IF;

        SELECT * INTO v_cycle
          FROM finance.subscription_cycles
         WHERE id = v_event.source_id
         FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Activated subscription cycle not found' USING ERRCODE = 'P0002';
        END IF;
        SELECT * INTO v_obligation FROM finance.obligations WHERE id = v_cycle.obligation_id FOR UPDATE;
        SELECT * INTO v_invoice FROM system.invoices WHERE id = v_cycle.invoice_id FOR UPDATE;
        SELECT * INTO v_billing FROM system.billing_accounts WHERE id = v_cycle.billing_account_id;
        SELECT * INTO v_plan FROM system.subscription_plans WHERE id = v_cycle.plan_id;
        SELECT * INTO v_settings FROM referrals.program_settings WHERE id = true;

        IF v_cycle.status <> 'active'
           OR v_cycle.annual_sequence <> 1
           OR v_cycle.cycle_type <> 'initial_annual' THEN
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'not_first_annual_activation', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'renewal_excluded'::text, NULL::uuid, NULL::text;
            RETURN;
        END IF;

        IF v_obligation.status <> 'settled'
           OR v_invoice.status <> 'paid'
           OR v_billing.account_type <> 'individual'
           OR v_plan.billing_cycle <> 'yearly'
           OR v_cycle.currency <> 'KES' THEN
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'activation_not_fully_settled', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'not_fully_settled'::text, NULL::uuid, NULL::text;
            RETURN;
        END IF;

        SELECT coalesce(sum(s.amount), 0) INTO v_settled_sum
          FROM finance.obligation_settlements s
         WHERE s.obligation_id = v_obligation.id;
        IF v_settled_sum < v_obligation.amount THEN
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'settlement_total_below_obligation', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'not_fully_settled'::text, NULL::uuid, NULL::text;
            RETURN;
        END IF;

        SELECT * INTO v_settlement
          FROM finance.obligation_settlements
         WHERE obligation_id = v_obligation.id
         ORDER BY settled_at DESC, id DESC
         LIMIT 1;
        SELECT * INTO v_payment FROM finance.payments WHERE id = v_settlement.payment_id;
        IF v_payment.id IS NULL OR v_payment.verified_at IS NULL
           OR v_payment.currency <> v_obligation.currency
           OR v_payment.amount < v_settlement.amount THEN
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'payment_evidence_invalid', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'payment_evidence_invalid'::text, NULL::uuid, NULL::text;
            RETURN;
        END IF;
        IF v_payment.payment_attempt_id IS NOT NULL THEN
            SELECT status INTO v_attempt_status
              FROM finance.payment_attempts
             WHERE id = v_payment.payment_attempt_id
               AND obligation_id = v_obligation.id;
            IF v_attempt_status IS DISTINCT FROM 'succeeded' THEN
                UPDATE referrals.event_consumptions
                   SET status = 'processed', processed_at = now(), last_error = 'payment_attempt_not_succeeded', updated_at = now()
                 WHERE id = v_consumption.id;
                RETURN QUERY SELECT p_event_id, 'payment_attempt_not_succeeded'::text, NULL::uuid, NULL::text;
                RETURN;
            END IF;
        END IF;

        v_settled_at := v_settlement.settled_at;

        SELECT * INTO v_referral
          FROM referrals.referrals
         WHERE referred_profile_id = v_cycle.subscriber_profile_id
         FOR UPDATE;
        IF NOT FOUND THEN
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'no_referral', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'no_referral'::text, NULL::uuid, NULL::text;
            RETURN;
        END IF;

        SELECT id INTO v_existing_reward FROM referrals.rewards WHERE referral_id = v_referral.id OR source_finance_event_id = p_event_id;
        IF v_existing_reward IS NOT NULL THEN
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'reward_already_exists', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'already_processed'::text, v_existing_reward, NULL::text;
            RETURN;
        END IF;

        IF v_referral.status IN ('ineligible', 'review_required') THEN
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'referral_not_eligible', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'referral_not_eligible'::text, NULL::uuid, NULL::text;
            RETURN;
        END IF;

        v_phone_hash := referrals.normalize_phone_hash((SELECT phone FROM users.profiles WHERE id = v_cycle.subscriber_profile_id));
        v_email_hash := referrals.normalize_email_hash((SELECT email FROM users.profiles WHERE id = v_cycle.subscriber_profile_id));

        IF referrals.is_employee_excluded(v_cycle.subscriber_profile_id, v_phone_hash, v_email_hash, v_settled_at) THEN
            UPDATE referrals.referrals SET status = 'ineligible', updated_at = now() WHERE id = v_referral.id;
            INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, reason, after_state)
            VALUES ('referral', v_referral.id, 'referral_employee_ineligible', 'vunio_employment_at_settlement',
                    jsonb_build_object('settled_at', v_settled_at));
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'employee_excluded', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'employee_excluded'::text, NULL::uuid, NULL::text;
            RETURN;
        END IF;

        SELECT status, reason INTO v_decision, v_reason
          FROM referrals.attribution_decision(
            v_referral.referrer_profile_id, v_cycle.subscriber_profile_id, v_phone_hash, v_email_hash
          );
        IF v_decision = 'ineligible' THEN
            UPDATE referrals.referrals SET status = 'ineligible', updated_at = now() WHERE id = v_referral.id;
            INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, reason, after_state)
            VALUES ('referral', v_referral.id, 'referral_self_ineligible', v_reason,
                    jsonb_build_object('settled_at', v_settled_at));
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'self_referral', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'self_referral'::text, NULL::uuid, NULL::text;
            RETURN;
        ELSIF v_decision = 'review_required' THEN
            UPDATE referrals.referrals SET status = 'review_required', updated_at = now() WHERE id = v_referral.id;
            INSERT INTO referrals.review_cases (referral_id, case_type, notes)
            VALUES (v_referral.id, 'self_referral', v_reason);
            INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, reason, after_state)
            VALUES ('referral', v_referral.id, 'referral_review_required', v_reason,
                    jsonb_build_object('settled_at', v_settled_at));
            UPDATE referrals.event_consumptions
               SET status = 'processed', processed_at = now(), last_error = 'review_required', updated_at = now()
             WHERE id = v_consumption.id;
            RETURN QUERY SELECT p_event_id, 'review_required'::text, NULL::uuid, NULL::text;
            RETURN;
        END IF;

        IF v_settings.reward_amount IS DISTINCT FROM 40 OR v_settings.currency <> 'KES' THEN
            RAISE EXCEPTION 'Referral programme settings are not the approved 40 KES';
        END IF;

        SELECT * INTO v_mapping FROM finance.referral_account_settings WHERE platform_entity_id = v_obligation.payee_entity_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Referral account mapping is missing' USING ERRCODE = '55000';
        END IF;

        INSERT INTO referrals.rewards (
            referral_id, beneficiary_profile_id, amount, currency, status, earned_at, source_finance_event_id
        ) VALUES (
            v_referral.id, v_referral.referrer_profile_id, v_settings.reward_amount, v_settings.currency,
            'pending', v_settled_at, p_event_id
        ) RETURNING id INTO v_reward_id;

        INSERT INTO finance.journals (
            entity_id, journal_date, currency, status, description, source_type, source_id, idempotency_key
        ) VALUES (
            v_obligation.payee_entity_id, v_settled_at::date, 'KES', 'draft',
            'Referral reward accrual ' || v_reward_id::text,
            'referral_reward', v_reward_id, 'referral-reward:' || v_reward_id::text
        ) RETURNING id INTO v_journal_id;

        INSERT INTO finance.journal_lines (
            journal_id, entity_id, currency, line_number, account_id, debit_amount, credit_amount, description
        ) VALUES
          (v_journal_id, v_obligation.payee_entity_id, 'KES', 1, v_mapping.expense_account_id,
           v_settings.reward_amount, 0, 'Referral reward expense'),
          (v_journal_id, v_obligation.payee_entity_id, 'KES', 2, v_mapping.payable_account_id,
           0, v_settings.reward_amount, 'Referral reward payable');
        PERFORM finance.post_journal(v_journal_id);

        UPDATE referrals.rewards
           SET status = 'eligible', accrual_journal_id = v_journal_id, accrued_at = now(), updated_at = now()
         WHERE id = v_reward_id;

        UPDATE referrals.referrals
           SET status = 'qualified', qualifying_cycle_id = v_cycle.id,
               qualifying_invoice_id = v_cycle.invoice_id,
               qualifying_obligation_id = v_cycle.obligation_id,
               qualifying_finance_event_id = p_event_id,
               earned_at = v_settled_at, qualified_at = now(), updated_at = now()
         WHERE id = v_referral.id;

        INSERT INTO referrals.reward_events (
            reward_id, event_type, amount, from_status, to_status, journal_id, metadata
        ) VALUES (
            v_reward_id, 'reward_qualified', v_settings.reward_amount, 'pending', 'eligible',
            v_journal_id, jsonb_build_object('finance_event_id', p_event_id, 'settled_at', v_settled_at)
        );
        INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, after_state)
        VALUES ('reward', v_reward_id, 'reward_qualified',
                jsonb_build_object('referral_id', v_referral.id, 'amount', v_settings.reward_amount, 'currency', v_settings.currency));

        UPDATE referrals.event_consumptions
           SET status = 'processed', processed_at = now(), last_error = NULL, updated_at = now()
         WHERE id = v_consumption.id;

        RETURN QUERY SELECT p_event_id, 'rewarded'::text, v_reward_id, NULL::text;
    EXCEPTION WHEN OTHERS THEN
        UPDATE referrals.event_consumptions
           SET status = 'failed', last_error = left(SQLERRM, 1000), updated_at = now()
         WHERE id = v_consumption.id;
        INSERT INTO referrals.event_failures (
            finance_event_id, event_type, attempts, last_error
        ) VALUES (
            p_event_id, v_event.event_type, greatest(v_consumption.attempts, 1), left(SQLERRM, 1000)
        ) ON CONFLICT ON CONSTRAINT event_failures_finance_event_id_key DO NOTHING;
        RETURN QUERY SELECT p_event_id, 'failed'::text, NULL::uuid, SQLERRM;
    END;
END;
$function$;

ALTER FUNCTION referrals.consume_finance_event_core(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION referrals.consume_finance_event_core(uuid)
    FROM PUBLIC, "anon", "authenticated", "service_role";

COMMIT;
