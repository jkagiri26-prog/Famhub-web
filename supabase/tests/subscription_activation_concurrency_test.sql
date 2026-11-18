-- ============================================================================
-- subscription_activation_concurrency_test.sql
-- ----------------------------------------------------------------------------
-- LOCAL-ONLY concurrency proof for finance.complete_annual_subscription.
--
-- Requires the dblink extension. Run only against a disposable local database.
-- This test commits its fixture because dblink uses separate sessions.
-- It leaves the append-only history in place; use a disposable database.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS dblink;

CREATE TEMP TABLE _activation_concurrency_fixture (
    cycle_id uuid,
    active_id uuid,
    invoice_id uuid,
    obligation_id uuid
) ON COMMIT PRESERVE ROWS;

DO $fixture$
DECLARE
    v_country_id uuid := gen_random_uuid();
    v_profile_id uuid := gen_random_uuid();
    v_entity_id uuid := gen_random_uuid();
    v_platform_id uuid := gen_random_uuid();
    v_billing_id uuid := gen_random_uuid();
    v_plan_id uuid;
    v_cycle_id uuid;
    v_active_id uuid;
    v_invoice_id uuid;
    v_obligation_id uuid;
    v_payment_id uuid;
    v_settled_at timestamptz := '2026-01-20 09:00:00+00'::timestamptz;
    v_suffix text := replace(clock_timestamp()::text, ' ', '');
BEGIN
    INSERT INTO core.countries(id, name, iso_alpha2, iso_alpha3, dialing_code)
    VALUES (v_country_id, 'Concurrency Testland', 'KE', 'KEN', '254');

    INSERT INTO users.profiles(id, first_name, country_id)
    VALUES (v_profile_id, 'Concurrency Tester', v_country_id);

    INSERT INTO core.entities(id, name, entity_type, owner_id, is_active, metadata) VALUES
      (v_entity_id, 'Concurrency Tester Entity', 'individual_pro', v_profile_id, true, '{}'::jsonb),
      (v_platform_id, 'Concurrency Platform', 'trading_company', v_profile_id, true,
       '{"platform_entity":"true","purpose":"platform_administration"}'::jsonb);

    INSERT INTO system.billing_accounts(id, entity_id, profile_id, account_type, status, currency)
    VALUES (v_billing_id, v_entity_id, v_profile_id, 'individual', 'active', 'KES');

    SELECT plan_id INTO v_plan_id
      FROM system.create_annual_subscription_plan(
        'conc-plan-' || v_suffix,
        'Concurrency Annual',
        12000,
        NULL,
        '{}'::jsonb
      );

    SELECT f.subscription_cycle_id, f.active_subscription_id, f.invoice_id, f.obligation_id
      INTO v_cycle_id, v_active_id, v_invoice_id, v_obligation_id
      FROM finance.create_annual_subscription(
        v_billing_id,
        v_plan_id,
        'CONC-INV-' || v_suffix,
        'conc-purchase-' || v_suffix,
        NULL,
        NULL
      ) AS f;

    INSERT INTO finance.payments (
        obligation_id, payer_entity_id, payee_entity_id, provider,
        provider_reference, amount, currency, verified_at
    ) VALUES (
        v_obligation_id, v_entity_id, v_platform_id, 'test',
        'CONC-PAY-' || v_suffix, 12000, 'KES', v_settled_at
    ) RETURNING id INTO v_payment_id;

    INSERT INTO finance.obligation_settlements (
        obligation_id, payment_id, currency, amount, settled_at, idempotency_key
    ) VALUES (
        v_obligation_id, v_payment_id, 'KES', 12000, v_settled_at,
        'conc-settle-' || v_suffix
    );

    UPDATE finance.obligations SET status = 'settled' WHERE id = v_obligation_id;

    INSERT INTO _activation_concurrency_fixture
    VALUES (v_cycle_id, v_active_id, v_invoice_id, v_obligation_id);
END;
$fixture$;

COMMIT;

DO $connect$
DECLARE
    v_conn text;
BEGIN
    SELECT format(
        'host=%s port=%s dbname=%s user=%s',
        split_part(setting, ',', 1),
        current_setting('port'),
        current_database(),
        current_user
    )
    INTO v_conn
    FROM pg_settings
    WHERE name = 'unix_socket_directories';

    PERFORM dblink_connect('activation_worker_1', v_conn);
    PERFORM dblink_connect('activation_worker_2', v_conn);
END;
$connect$;

-- Hold the cycle row lock, start both workers, then release the lock.
BEGIN;

SELECT 1
  FROM finance.subscription_cycles
 WHERE id = (SELECT cycle_id FROM _activation_concurrency_fixture)
 FOR UPDATE;

SELECT dblink_send_query(
    'activation_worker_1',
    format(
        'SELECT * FROM finance.complete_annual_subscription(%L)',
        (SELECT cycle_id FROM _activation_concurrency_fixture)
    )
);

SELECT dblink_send_query(
    'activation_worker_2',
    format(
        'SELECT * FROM finance.complete_annual_subscription(%L)',
        (SELECT cycle_id FROM _activation_concurrency_fixture)
    )
);

COMMIT;

DO $verify$
DECLARE
    v_cycle_id uuid := (SELECT cycle_id FROM _activation_concurrency_fixture);
    v_active_id uuid := (SELECT active_id FROM _activation_concurrency_fixture);
    v_invoice_id uuid := (SELECT invoice_id FROM _activation_concurrency_fixture);
    v_worker_1 record;
    v_worker_2 record;
    v_count bigint;
BEGIN
    SELECT * INTO v_worker_1
      FROM dblink_get_result('activation_worker_1') AS t(
        subscription_cycle_id uuid,
        active_subscription_id uuid,
        invoice_id uuid,
        obligation_id uuid,
        settlement_id uuid,
        payment_id uuid,
        settled_at timestamptz,
        annual_sequence integer,
        cycle_type text,
        period_start date,
        period_end date,
        amount numeric,
        currency text,
        status text,
        event_id uuid
      );

    SELECT * INTO v_worker_2
      FROM dblink_get_result('activation_worker_2') AS t(
        subscription_cycle_id uuid,
        active_subscription_id uuid,
        invoice_id uuid,
        obligation_id uuid,
        settlement_id uuid,
        payment_id uuid,
        settled_at timestamptz,
        annual_sequence integer,
        cycle_type text,
        period_start date,
        period_end date,
        amount numeric,
        currency text,
        status text,
        event_id uuid
      );

    IF v_worker_1.subscription_cycle_id IS DISTINCT FROM v_cycle_id
       OR v_worker_2.subscription_cycle_id IS DISTINCT FROM v_cycle_id THEN
        RAISE EXCEPTION 'worker results do not reference the fixture cycle';
    END IF;
    IF v_worker_1.event_id IS DISTINCT FROM v_worker_2.event_id THEN
        RAISE EXCEPTION 'workers returned different activation events';
    END IF;

    SELECT count(*) INTO v_count
      FROM finance.events
     WHERE idempotency_key = 'subscription-cycle-activated:' || v_cycle_id::text;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'expected one activation event, found %', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM system.invoices
     WHERE id = v_invoice_id AND status = 'paid';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'expected one paid invoice, found %', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM system.active_subscriptions
     WHERE id = v_active_id AND status = 'active';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'expected one active subscription, found %', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM finance.subscription_cycles
     WHERE id = v_cycle_id AND status = 'active';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'expected one active cycle, found %', v_count;
    END IF;
END;
$verify$;

SELECT dblink_disconnect('activation_worker_1');
SELECT dblink_disconnect('activation_worker_2');
