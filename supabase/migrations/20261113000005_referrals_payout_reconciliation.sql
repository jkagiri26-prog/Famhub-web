-- ============================================================================
-- 20261113000005_referrals_payout_reconciliation
-- ----------------------------------------------------------------------------
-- Forward-only manual M-Pesa payout reconciliation for Refer & Earn.
-- Uses the existing Finance payment, journal, settlement and obligation tables.
-- The payout journal is posted on the platform entity:
--   debit  Referral Rewards Payable (2400)
--   credit M-Pesa Platform Collections Clearing (1000)
-- This is an outbound payout, not a customer collection.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION "referrals"."record_manual_payout"(
    p_request_id uuid,
    p_mpesa_receipt text,
    p_payout_evidence jsonb,
    p_paid_at timestamp with time zone DEFAULT now()
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, referrals, finance, core
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

    -- The request and receipt uniquely identify the payout. The database
    -- constraints also prevent duplicate request receipts and provider refs.
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
        withdrawal_request_id, event_type, from_status, to_status, amount,
        mpesa_receipt, evidence
    ) VALUES (
        v_request.id, 'withdrawal_paid', 'approved', 'paid', v_request.amount,
        v_receipt, p_payout_evidence
    );
    INSERT INTO referrals.audit_events (entity_type, entity_id, event_type, after_state)
    VALUES ('withdrawal', v_request.id, 'withdrawal_paid',
            jsonb_build_object('mpesa_receipt', v_receipt, 'amount', v_request.amount,
                               'payment_id', v_payment.id, 'settlement_id', v_settlement.id,
                               'journal_id', v_journal_id));
END;
$function$;

REVOKE ALL ON FUNCTION "referrals"."record_manual_payout"(uuid, text, jsonb, timestamp with time zone)
    FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "referrals"."record_manual_payout"(uuid, text, jsonb, timestamp with time zone)
    TO "service_role";

COMMIT;
