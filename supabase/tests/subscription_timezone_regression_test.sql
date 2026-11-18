-- ============================================================================
-- subscription_timezone_regression_test.sql
-- ----------------------------------------------------------------------------
-- LOCAL-ONLY timezone regression test for annual purchase and activation.
--
-- Proves that explicit Africa/Nairobi conversions do not depend on the
-- PostgreSQL session timezone. Run against a disposable local database.
-- ============================================================================

BEGIN;

INSERT INTO core.countries(id, name, iso_alpha2, iso_alpha3, dialing_code)
VALUES ('00000000-0000-0000-0000-000000007001', 'Timezone Testland', 'KE', 'KEN', '254');

INSERT INTO users.profiles(id, first_name, country_id)
VALUES
  ('00000000-0000-0000-0000-000000007002', 'Timezone UTC Tester', '00000000-0000-0000-0000-000000007001'),
  ('00000000-0000-0000-0000-000000007012', 'Timezone LA Tester', '00000000-0000-0000-0000-000000007001');

INSERT INTO core.entities(id, name, entity_type, owner_id, is_active, metadata) VALUES
  ('00000000-0000-0000-0000-000000007003', 'Timezone UTC Entity', 'individual_pro', '00000000-0000-0000-0000-000000007002', true, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000007013', 'Timezone LA Entity', 'individual_pro', '00000000-0000-0000-0000-000000007012', true, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000007004', 'Timezone Platform', 'trading_company', '00000000-0000-0000-0000-000000007002', true, '{"platform_entity":"true","purpose":"platform_administration"}'::jsonb);

INSERT INTO system.billing_accounts(id, entity_id, profile_id, account_type, status, currency)
VALUES
  ('00000000-0000-0000-0000-000000007005', '00000000-0000-0000-0000-000000007003', '00000000-0000-0000-0000-000000007002', 'individual', 'active', 'KES'),
  ('00000000-0000-0000-0000-000000007015', '00000000-0000-0000-0000-000000007013', '00000000-0000-0000-0000-000000007012', 'individual', 'active', 'KES');

CREATE TEMP TABLE _timezone_accounts (
    label text PRIMARY KEY,
    entity_id uuid NOT NULL,
    billing_id uuid NOT NULL
) ON COMMIT DROP;

INSERT INTO _timezone_accounts(label, entity_id, billing_id) VALUES
  ('UTC', '00000000-0000-0000-0000-000000007003', '00000000-0000-0000-0000-000000007005'),
  ('America/Los_Angeles', '00000000-0000-0000-0000-000000007013', '00000000-0000-0000-0000-000000007015');

CREATE TEMP TABLE _timezone_results (
    label text PRIMARY KEY,
    purchase_start timestamptz NOT NULL,
    purchase_end timestamptz NOT NULL,
    activation_start timestamptz,
    activation_end timestamptz
) ON COMMIT DROP;

CREATE OR REPLACE FUNCTION pg_temp.make_cycle(
    p_suffix text,
    p_plan_id uuid,
    p_billing_account_id uuid,
    p_start date
)
RETURNS TABLE (
    cycle_id uuid,
    active_id uuid,
    invoice_id uuid,
    obligation_id uuid
)
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT f.subscription_cycle_id, f.active_subscription_id, f.invoice_id, f.obligation_id
      FROM finance.create_annual_subscription(
        p_billing_account_id,
        p_plan_id,
        'TZ-INV-' || p_suffix,
        'tz-purchase-' || p_suffix,
        p_start,
        NULL
      ) AS f;
END;
$function$;

DO $test$
DECLARE
    v_tz text;
    v_suffix text;
    v_plan_id uuid;
    v_entity_id uuid;
    v_billing_id uuid;
    v_cycle_id uuid;
    v_active_id uuid;
    v_invoice_id uuid;
    v_obligation_id uuid;
    v_payment_id uuid;
    v_purchase_start timestamptz;
    v_purchase_end timestamptz;
    v_activation_start timestamptz;
    v_activation_end timestamptz;
    v_settled_at timestamptz := '2026-12-31 10:00:00+00'::timestamptz;
    v_result record;
BEGIN
    SELECT plan_id INTO v_plan_id
      FROM system.create_annual_subscription_plan(
        'timezone-test-plan',
        'Timezone Test Annual',
        12000,
        NULL,
        '{}'::jsonb
      );

    FOREACH v_tz IN ARRAY ARRAY['UTC', 'America/Los_Angeles'] LOOP
        PERFORM set_config('TimeZone', v_tz, true);
        v_suffix := replace(v_tz, '/', '-');
        SELECT entity_id, billing_id
          INTO v_entity_id, v_billing_id
          FROM _timezone_accounts
         WHERE label = v_tz;

        -- Purchase conversion: a future cycle starting 31 December.
        SELECT cycle_id, active_id, invoice_id, obligation_id
          INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
          FROM pg_temp.make_cycle(
            'purchase-' || v_suffix,
            v_plan_id,
            v_billing_id,
            '2026-12-31'
          );

        SELECT start_date, end_date
          INTO v_purchase_start, v_purchase_end
          FROM system.active_subscriptions
         WHERE id = v_active_id;

        IF v_purchase_start IS DISTINCT FROM '2026-12-30 21:00:00+00'::timestamptz THEN
            RAISE EXCEPTION 'purchase start under % was %, expected 2026-12-30 21:00 UTC',
                v_tz, v_purchase_start;
        END IF;
        IF v_purchase_end IS DISTINCT FROM '2027-12-30 21:00:00+00'::timestamptz THEN
            RAISE EXCEPTION 'purchase end under % was %, expected 2027-12-30 21:00 UTC',
                v_tz, v_purchase_end;
        END IF;

        INSERT INTO _timezone_results(label, purchase_start, purchase_end)
        VALUES (v_tz, v_purchase_start, v_purchase_end);

        -- Activation conversion: a cycle ending 31 December 2026.
        SELECT cycle_id, active_id, invoice_id, obligation_id
          INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
          FROM pg_temp.make_cycle(
            'activation-' || v_suffix,
            v_plan_id,
            v_billing_id,
            '2026-12-31'
          );

        UPDATE finance.subscription_cycles
           SET period_start = '2026-01-01',
               period_end = '2026-12-31'
         WHERE id = v_cycle_id;

        INSERT INTO finance.payments (
            obligation_id, payer_entity_id, payee_entity_id, provider,
            provider_reference, amount, currency, verified_at
        ) VALUES (
            v_obligation_id,
            v_entity_id,
            '00000000-0000-0000-0000-000000007004',
            'test', 'TZ-PAY-' || v_suffix, 12000, 'KES', v_settled_at
        ) RETURNING id INTO v_payment_id;

        INSERT INTO finance.obligation_settlements (
            obligation_id, payment_id, currency, amount, settled_at, idempotency_key
        ) VALUES (
            v_obligation_id, v_payment_id, 'KES', 12000, v_settled_at,
            'tz-settle-' || v_suffix
        );

        UPDATE finance.obligations SET status = 'settled' WHERE id = v_obligation_id;

        SELECT * INTO v_result
          FROM finance.complete_annual_subscription(v_cycle_id, v_obligation_id);

        IF v_result.status <> 'active' THEN
            RAISE EXCEPTION 'activation under % returned status %', v_tz, v_result.status;
        END IF;

        SELECT start_date, end_date
          INTO v_activation_start, v_activation_end
          FROM system.active_subscriptions
         WHERE id = v_active_id;

        UPDATE _timezone_results
           SET activation_start = v_activation_start,
               activation_end = v_activation_end
         WHERE label = v_tz;
    END LOOP;

    IF v_activation_start IS DISTINCT FROM '2025-12-31 21:00:00+00'::timestamptz THEN
        RAISE EXCEPTION 'activation start was %, expected midnight Africa/Nairobi on 2026-01-01',
            v_activation_start;
    END IF;
    IF v_activation_end IS DISTINCT FROM '2026-12-31 21:00:00+00'::timestamptz THEN
        RAISE EXCEPTION 'activation end was %, expected 2026-12-31 21:00 UTC', v_activation_end;
    END IF;

    IF NOT ('2026-12-31 20:59:59.999+00'::timestamptz < v_activation_end) THEN
        RAISE EXCEPTION 'immediately before expiry should be entitled';
    END IF;
    IF '2026-12-31 21:00:00+00'::timestamptz < v_activation_end THEN
        RAISE EXCEPTION 'exactly at expiry should not be entitled';
    END IF;
    IF '2026-12-31 21:00:00.001+00'::timestamptz < v_activation_end THEN
        RAISE EXCEPTION 'immediately after expiry should not be entitled';
    END IF;

    IF (SELECT count(*) FROM _timezone_results) <> 2 THEN
        RAISE EXCEPTION 'expected two timezone result rows';
    END IF;
    IF (
        SELECT count(DISTINCT (purchase_start, purchase_end, activation_start, activation_end))
          FROM _timezone_results
    ) <> 1 THEN
        RAISE EXCEPTION 'stored timestamps differ across session timezones';
    END IF;
END;
$test$;

ROLLBACK;
