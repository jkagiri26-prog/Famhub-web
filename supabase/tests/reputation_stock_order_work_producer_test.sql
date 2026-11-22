-- ============================================================================
-- reputation_stock_order_work_producer_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE test for Phase 2C-5.
--
-- Run only against a local/disposable database with all migrations applied.
-- Never run against production.
-- ============================================================================
BEGIN;

-- ---------------------------------------------------------------------------
-- Minimal Commerce/Marketplace fixture graph.
-- ---------------------------------------------------------------------------
INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('c5000000-0000-4000-8000-000000000001', 'Producer Test Country', 'PC', 'PCT', '9994', true);

INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('c5000000-0000-4000-8000-000000000002', 'Producer Test Location',
        'c5000000-0000-4000-8000-000000000001', true);

INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('c5000000-0000-4000-8000-000000000003', 'producer-test-kilogram', 'kg', 'mass');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', 'service_role', true),
    set_config('request.jwt.claims', '{"role":"service_role"}', true);

INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
    ('c5000000-0000-4000-8000-000000000101', 'c5000000-0000-4000-8000-000000000901',
     'Producer Buyer', 'c5000000-0000-4000-8000-000000000001', true, 'active'),
    ('c5000000-0000-4000-8000-000000000102', 'c5000000-0000-4000-8000-000000000902',
     'Producer Seller', 'c5000000-0000-4000-8000-000000000001', true, 'active');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', '', true),
    set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, verification_status)
VALUES
    ('c5000000-0000-4000-8000-000000000201', 'Producer Buyer Entity',
     'individual_pro', 'c5000000-0000-4000-8000-000000000101', true, 'verified'),
    ('c5000000-0000-4000-8000-000000000202', 'Producer Seller Entity',
     'farm', 'c5000000-0000-4000-8000-000000000102', true, 'verified');

INSERT INTO core.items (id, name)
VALUES ('c5000000-0000-4000-8000-000000000301', 'Producer Test Item');

INSERT INTO core.item_variants (id, item_id, name)
VALUES ('c5000000-0000-4000-8000-000000000302',
        'c5000000-0000-4000-8000-000000000301', 'Producer Test Variant');

INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES (
    'c5000000-0000-4000-8000-000000000401', 'farm',
    'c5000000-0000-4000-8000-000000000102', 'Producer Test Supplier',
    'verified', true, 'c5000000-0000-4000-8000-000000000202', true
);

INSERT INTO commerce.stock_registry (
    id, entity_id, business_profile_id, variant_id, product_id, location_id,
    quantity, reserved_quantity, unit_id, status
) VALUES (
    'c5000000-0000-4000-8000-000000000402',
    'c5000000-0000-4000-8000-000000000202',
    'c5000000-0000-4000-8000-000000000401',
    'c5000000-0000-4000-8000-000000000302',
    'c5000000-0000-4000-8000-000000000301',
    'c5000000-0000-4000-8000-000000000002',
    1000.00, 0.00, 'c5000000-0000-4000-8000-000000000003', 'active'
);

INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status, stock_id
) VALUES (
    'c5000000-0000-4000-8000-000000000501',
    'c5000000-0000-4000-8000-000000000202',
    'Producer Test Listing', 50.00, 'KES',
    'c5000000-0000-4000-8000-000000000002',
    'c5000000-0000-4000-8000-000000000302',
    1000.00, 'c5000000-0000-4000-8000-000000000003', 'active',
    'c5000000-0000-4000-8000-000000000402'
);

CREATE FUNCTION pg_temp.insert_producer_order(
    p_id uuid,
    p_status text,
    p_order_kind text,
    p_delivered_at timestamptz
)
RETURNS void
LANGUAGE sql
AS $function$
    INSERT INTO commerce.orders (
        id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
        payment_status, order_date, delivered_at, delivery_date, entity_id,
        order_kind, buyer_entity_id, seller_entity_id, currency, unit_id,
        status_changed_by_profile_id
    ) VALUES (
        p_id,
        'c5000000-0000-4000-8000-000000000101',
        'c5000000-0000-4000-8000-000000000501',
        'c5000000-0000-4000-8000-000000000401',
        1.00, 50.00, p_status, 'pending',
        '2026-11-22T08:00:00Z', p_delivered_at, p_delivered_at,
        'c5000000-0000-4000-8000-000000000202',
        p_order_kind,
        'c5000000-0000-4000-8000-000000000201',
        'c5000000-0000-4000-8000-000000000202',
        'KES', 'c5000000-0000-4000-8000-000000000003',
        'c5000000-0000-4000-8000-000000000101'
    );
$function$;

CREATE FUNCTION pg_temp.work_count(p_order_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
AS $function$
    SELECT count(*)::integer
      FROM reputation.processing_work w
     WHERE w.work_kind = 'stock_order_engagement_ingestion'
       AND w.source_system = 'vunio'
       AND w.source_reference = p_order_id::text;
$function$;

-- ---------------------------------------------------------------------------
-- Structural/security checks.
-- ---------------------------------------------------------------------------
DO $structure$
DECLARE
    v_trigger record;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='reputation'
           AND p.proname='enqueue_stock_order_delivery_work'
           AND p.prosecdef = true
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.proconfig @> ARRAY['search_path=pg_catalog, reputation']
    ) THEN
        RAISE EXCEPTION 'trigger function security properties are wrong';
    END IF;

    IF has_function_privilege('service_role', 'reputation.enqueue_stock_order_delivery_work()', 'EXECUTE')
       OR has_function_privilege('authenticated', 'reputation.enqueue_stock_order_delivery_work()', 'EXECUTE')
       OR has_function_privilege('anon', 'reputation.enqueue_stock_order_delivery_work()', 'EXECUTE') THEN
        RAISE EXCEPTION 'trigger function is directly executable by an API role';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc p
        CROSS JOIN LATERAL aclexplode(p.proacl) a
        WHERE p.oid = 'reputation.enqueue_stock_order_delivery_work()'::regprocedure
          AND a.grantee = 0
          AND a.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'trigger function is executable by PUBLIC';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='system'
           AND p.proname='backfill_reputation_stock_order_work'
           AND p.prosecdef = true
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.proconfig @> ARRAY['search_path=pg_catalog']
    ) THEN
        RAISE EXCEPTION 'backfill function security properties are wrong';
    END IF;

    IF pg_get_function_result(
           'system.backfill_reputation_stock_order_work(integer,uuid)'::regprocedure
       ) LIKE '%failed_message%'
       OR pg_get_function_result(
           'system.backfill_reputation_stock_order_work(integer,uuid)'::regprocedure
       ) NOT LIKE '%failed_error_class%' THEN
        RAISE EXCEPTION 'backfill return contract still exposes raw error text';
    END IF;

    IF NOT has_function_privilege('service_role', 'system.backfill_reputation_stock_order_work(integer,uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'system.backfill_reputation_stock_order_work(integer,uuid)', 'EXECUTE')
       OR has_function_privilege('anon', 'system.backfill_reputation_stock_order_work(integer,uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'backfill grants are wrong';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc p
        CROSS JOIN LATERAL aclexplode(p.proacl) a
        WHERE p.oid = 'system.backfill_reputation_stock_order_work(integer,uuid)'::regprocedure
          AND a.grantee = 0
          AND a.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'backfill function is executable by PUBLIC';
    END IF;

    SELECT t.tgname, pg_get_triggerdef(t.oid) AS definition
      INTO v_trigger
      FROM pg_trigger t
      JOIN pg_class c ON c.oid=t.tgrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='commerce' AND c.relname='orders'
       AND t.tgname='reputation_stock_order_delivery_work_insert';
    IF NOT FOUND OR v_trigger.definition NOT LIKE '%AFTER INSERT%' THEN
        RAISE EXCEPTION 'INSERT trigger definition is wrong';
    END IF;

    SELECT t.tgname, pg_get_triggerdef(t.oid) AS definition
      INTO v_trigger
      FROM pg_trigger t
      JOIN pg_class c ON c.oid=t.tgrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='commerce' AND c.relname='orders'
       AND t.tgname='reputation_stock_order_delivery_work_update';
    IF NOT FOUND
       OR v_trigger.definition NOT LIKE '%AFTER UPDATE OF status, order_kind, delivered_at%'
       OR v_trigger.definition NOT LIKE '%WHEN%' THEN
        RAISE EXCEPTION 'UPDATE trigger definition is wrong';
    END IF;
END;
$structure$;

-- ---------------------------------------------------------------------------
-- Trigger behaviour.
-- ---------------------------------------------------------------------------
DO $trigger_behaviour$
DECLARE
    v_count integer;
    v_now timestamptz := clock_timestamp();
BEGIN
    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000001', 'shipped', 'stock', NULL
    );
    IF pg_temp.work_count('a5000000-0000-4000-8000-000000000001') <> 0 THEN
        RAISE EXCEPTION 'shipped order created work';
    END IF;

    UPDATE commerce.orders
       SET status = 'delivered',
           delivered_at = clock_timestamp(),
           delivery_date = clock_timestamp(),
           updated_at = clock_timestamp()
     WHERE id = 'a5000000-0000-4000-8000-000000000001';
    IF pg_temp.work_count('a5000000-0000-4000-8000-000000000001') <> 1 THEN
        RAISE EXCEPTION 'shipped->delivered did not create exactly one work row';
    END IF;

    UPDATE commerce.orders
       SET status = 'delivered',
           status_reason = 'repeated delivery update',
           updated_at = clock_timestamp()
     WHERE id = 'a5000000-0000-4000-8000-000000000001';
    IF pg_temp.work_count('a5000000-0000-4000-8000-000000000001') <> 1 THEN
        RAISE EXCEPTION 'repeated eligible update duplicated work';
    END IF;

    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000002', 'delivered', 'stock', clock_timestamp()
    );
    IF pg_temp.work_count('a5000000-0000-4000-8000-000000000002') <> 1 THEN
        RAISE EXCEPTION 'delivered stock INSERT did not create work';
    END IF;

    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000003', 'delivered', 'service', clock_timestamp()
    );
    IF pg_temp.work_count('a5000000-0000-4000-8000-000000000003') <> 0 THEN
        RAISE EXCEPTION 'delivered service order created work';
    END IF;

    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000011', 'delivered', 'stock', NULL
    );
    IF pg_temp.work_count('a5000000-0000-4000-8000-000000000011') <> 0 THEN
        RAISE EXCEPTION 'delivered order without delivered_at created work';
    END IF;

    UPDATE commerce.orders
       SET delivered_at = clock_timestamp(),
           delivery_date = clock_timestamp(),
           updated_at = clock_timestamp()
     WHERE id = 'a5000000-0000-4000-8000-000000000011';
    IF pg_temp.work_count('a5000000-0000-4000-8000-000000000011') <> 1 THEN
        RAISE EXCEPTION 'ineligible-to-eligible update did not create work';
    END IF;

    -- Unrelated update after an eligible insert must not enqueue again.
    DELETE FROM reputation.processing_work
     WHERE source_reference = 'a5000000-0000-4000-8000-000000000002';
    UPDATE commerce.orders
       SET payment_status = 'completed',
           status_reason = 'unrelated update',
           updated_at = clock_timestamp()
     WHERE id = 'a5000000-0000-4000-8000-000000000002';
    IF pg_temp.work_count('a5000000-0000-4000-8000-000000000002') <> 0 THEN
        RAISE EXCEPTION 'unrelated delivered-order update enqueued work';
    END IF;

    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000013', 'shipped', 'stock', NULL
    );
    INSERT INTO reputation.processing_work (
        work_kind, source_system, source_reference, status, attempt_count,
        max_attempts, next_attempt_at, dead_letter_reason_code,
        dead_lettered_at, created_at, updated_at
    ) VALUES (
        'stock_order_engagement_ingestion', 'vunio',
        'a5000000-0000-4000-8000-000000000013',
        'dead_letter', 1, 5, v_now,
        'fixture_terminal', v_now, v_now, v_now
    );
    UPDATE commerce.orders
       SET status = 'delivered',
           delivered_at = clock_timestamp(),
           delivery_date = clock_timestamp(),
           updated_at = clock_timestamp()
     WHERE id = 'a5000000-0000-4000-8000-000000000013';
    SELECT count(*) INTO v_count
      FROM reputation.processing_work
     WHERE source_reference = 'a5000000-0000-4000-8000-000000000013'
       AND status = 'dead_letter';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'terminal work was duplicated or reopened';
    END IF;
END;
$trigger_behaviour$;

DO $non_delivered_statuses$
BEGIN
    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000004', 'pending', 'stock', NULL
    );
    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000005', 'accepted', 'stock', NULL
    );
    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000006', 'confirmed', 'stock', NULL
    );
    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000007', 'shipped', 'stock', NULL
    );
    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000008', 'rejected', 'stock', NULL
    );
    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000009', 'cancelled', 'stock', NULL
    );
    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000010', 'returned', 'stock', NULL
    );

    IF (SELECT sum(pg_temp.work_count(id))
          FROM commerce.orders
         WHERE id IN (
             'a5000000-0000-4000-8000-000000000004',
             'a5000000-0000-4000-8000-000000000005',
             'a5000000-0000-4000-8000-000000000006',
             'a5000000-0000-4000-8000-000000000007',
             'a5000000-0000-4000-8000-000000000008',
             'a5000000-0000-4000-8000-000000000009',
             'a5000000-0000-4000-8000-000000000010'
         )) <> 0 THEN
        RAISE EXCEPTION 'non-delivered order created work';
    END IF;
END;
$non_delivered_statuses$;

DO $rollback_on_failure$
DECLARE
    v_status text;
    v_delivered_at timestamptz;
    v_sqlstate text;
    v_message text;
BEGIN
    PERFORM pg_temp.insert_producer_order(
        'a5000000-0000-4000-8000-000000000014', 'shipped', 'stock', NULL
    );

    CREATE OR REPLACE FUNCTION pg_temp.fail_producer_enqueue()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $function$
    BEGIN
        IF NEW.source_reference = 'a5000000-0000-4000-8000-000000000014' THEN
            RAISE EXCEPTION 'forced enqueue failure';
        END IF;
        RETURN NEW;
    END;
    $function$;

    CREATE TRIGGER fail_producer_enqueue
        BEFORE INSERT ON reputation.processing_work
        FOR EACH ROW
        EXECUTE FUNCTION pg_temp.fail_producer_enqueue();

    BEGIN
        UPDATE commerce.orders
           SET status = 'delivered',
               delivered_at = clock_timestamp(),
               delivery_date = clock_timestamp(),
               updated_at = clock_timestamp()
         WHERE id = 'a5000000-0000-4000-8000-000000000014';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_sqlstate = RETURNED_SQLSTATE,
            v_message = MESSAGE_TEXT;
    END;

    DROP TRIGGER fail_producer_enqueue ON reputation.processing_work;

    IF v_sqlstate <> 'P2C05'
       OR v_message <> 'Delivery processing is temporarily unavailable' THEN
        RAISE EXCEPTION 'delivery error was not sanitized: %/%', v_sqlstate, v_message;
    END IF;

    SELECT status, delivered_at INTO v_status, v_delivered_at
      FROM commerce.orders
     WHERE id = 'a5000000-0000-4000-8000-000000000014';

    IF v_status <> 'shipped' OR v_delivered_at IS NOT NULL THEN
        RAISE EXCEPTION 'delivery update did not roll back after enqueue failure';
    END IF;
    IF pg_temp.work_count('a5000000-0000-4000-8000-000000000014') <> 0 THEN
        RAISE EXCEPTION 'enqueue failure left a work row';
    END IF;
END;
$rollback_on_failure$;

-- ---------------------------------------------------------------------------
-- Backfill selection, accounting, pagination, retry and failure boundaries.
-- ---------------------------------------------------------------------------
DO $backfill_setup$
BEGIN
    PERFORM pg_temp.insert_producer_order('f5000000-0000-4000-8000-000000000001', 'delivered', 'stock', clock_timestamp());
    PERFORM pg_temp.insert_producer_order('f5000000-0000-4000-8000-000000000002', 'delivered', 'stock', clock_timestamp());
    PERFORM pg_temp.insert_producer_order('f5000000-0000-4000-8000-000000000003', 'delivered', 'stock', clock_timestamp());
    PERFORM pg_temp.insert_producer_order('f5000000-0000-4000-8000-000000000004', 'delivered', 'stock', clock_timestamp());
    PERFORM pg_temp.insert_producer_order('f5000000-0000-4000-8000-000000000005', 'delivered', 'service', clock_timestamp());
    PERFORM pg_temp.insert_producer_order('f5000000-0000-4000-8000-000000000006', 'shipped', 'stock', NULL);
    PERFORM pg_temp.insert_producer_order('f5000000-0000-4000-8000-000000000007', 'delivered', 'stock', NULL);

    DELETE FROM reputation.processing_work
     WHERE source_reference IN (
         'f5000000-0000-4000-8000-000000000001',
         'f5000000-0000-4000-8000-000000000002',
         'f5000000-0000-4000-8000-000000000003',
         'f5000000-0000-4000-8000-000000000004'
     );
END;
$backfill_setup$;

DO $backfill_pagination$
DECLARE
    v_result record;
    v_count integer;
    v_updated_before timestamptz;
    v_updated_after timestamptz;
BEGIN
    IF EXISTS (
        SELECT 1 FROM reputation.processing_work
         WHERE source_reference IN (
             'f5000000-0000-4000-8000-000000000001',
             'f5000000-0000-4000-8000-000000000002',
             'f5000000-0000-4000-8000-000000000003',
             'f5000000-0000-4000-8000-000000000004'
         )
    ) THEN
        RAISE EXCEPTION 'backfill setup did not clear work rows';
    END IF;

    SELECT updated_at INTO v_updated_before
      FROM commerce.orders
     WHERE id='f5000000-0000-4000-8000-000000000001';

    SELECT * INTO v_result
      FROM system.backfill_reputation_stock_order_work(
          2, 'f4000000-0000-4000-8000-000000000000'
      );
    IF v_result.scanned_count <> 2
       OR v_result.enqueued_count <> 2
       OR v_result.existing_count <> 0
       OR v_result.failed_count <> 0
       OR v_result.last_processed_order_id <> 'f5000000-0000-4000-8000-000000000002' THEN
        RAISE EXCEPTION 'first backfill page accounting/cursor is wrong: %', v_result;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.processing_work
     WHERE source_reference IN (
         'f5000000-0000-4000-8000-000000000001',
         'f5000000-0000-4000-8000-000000000002'
     );
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'first backfill page did not create two work rows';
    END IF;

    SELECT * INTO v_result
      FROM system.backfill_reputation_stock_order_work(
          2, 'f5000000-0000-4000-8000-000000000002'
      );
    IF v_result.scanned_count <> 2
       OR v_result.enqueued_count <> 2
       OR v_result.existing_count <> 0
       OR v_result.failed_count <> 0
       OR v_result.last_processed_order_id <> 'f5000000-0000-4000-8000-000000000004' THEN
        RAISE EXCEPTION 'second backfill page accounting/cursor is wrong: %', v_result;
    END IF;

    SELECT * INTO v_result
      FROM system.backfill_reputation_stock_order_work(
          2, 'f5000000-0000-4000-8000-000000000004'
      );
    IF v_result.scanned_count <> 0
       OR v_result.enqueued_count <> 0
       OR v_result.existing_count <> 0
       OR v_result.failed_count <> 0
       OR v_result.last_processed_order_id IS NOT NULL THEN
        RAISE EXCEPTION 'backfill completion page is wrong: %', v_result;
    END IF;

    -- Retrying the first page must not duplicate or reopen work.
    SELECT * INTO v_result
      FROM system.backfill_reputation_stock_order_work(
          2, 'f4000000-0000-4000-8000-000000000000'
      );
    IF v_result.scanned_count <> 2
       OR v_result.enqueued_count <> 0
       OR v_result.existing_count <> 2
       OR v_result.failed_count <> 0
       OR v_result.last_processed_order_id <> 'f5000000-0000-4000-8000-000000000002' THEN
        RAISE EXCEPTION 'backfill retry accounting is wrong: %', v_result;
    END IF;

    SELECT updated_at INTO v_updated_after
      FROM commerce.orders
     WHERE id='f5000000-0000-4000-8000-000000000001';
    IF v_updated_after IS DISTINCT FROM v_updated_before THEN
        RAISE EXCEPTION 'backfill modified a Commerce order';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.processing_work
     WHERE source_reference IN (
         'f5000000-0000-4000-8000-000000000005',
         'f5000000-0000-4000-8000-000000000006',
         'f5000000-0000-4000-8000-000000000007'
     );
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'backfill selected an ineligible order';
    END IF;
END;
$backfill_pagination$;

DO $backfill_failure$
DECLARE
    v_result record;
    v_retry record;
BEGIN
    PERFORM pg_temp.insert_producer_order('f5000000-0000-4000-8000-000000000008', 'delivered', 'stock', clock_timestamp());
    PERFORM pg_temp.insert_producer_order('f5000000-0000-4000-8000-000000000009', 'delivered', 'stock', clock_timestamp());
    PERFORM pg_temp.insert_producer_order('f5000000-0000-4000-8000-000000000010', 'delivered', 'stock', clock_timestamp());

    DELETE FROM reputation.processing_work
     WHERE source_reference IN (
         'f5000000-0000-4000-8000-000000000008',
         'f5000000-0000-4000-8000-000000000009',
         'f5000000-0000-4000-8000-000000000010'
     );

    CREATE OR REPLACE FUNCTION pg_temp.fail_backfill_enqueue()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $function$
    BEGIN
        IF NEW.source_reference = 'f5000000-0000-4000-8000-000000000009' THEN
            RAISE EXCEPTION 'forced backfill enqueue failure';
        END IF;
        RETURN NEW;
    END;
    $function$;

    CREATE TRIGGER fail_backfill_enqueue
        BEFORE INSERT ON reputation.processing_work
        FOR EACH ROW
        EXECUTE FUNCTION pg_temp.fail_backfill_enqueue();

    BEGIN
        SELECT * INTO v_result
          FROM system.backfill_reputation_stock_order_work(
              10, 'f5000000-0000-4000-8000-000000000007'
          );
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'backfill did not report the first failure: %', SQLERRM;
    END;

    DROP TRIGGER fail_backfill_enqueue ON reputation.processing_work;

    IF v_result.scanned_count <> 2
       OR v_result.enqueued_count <> 1
       OR v_result.existing_count <> 0
       OR v_result.failed_count <> 1
       OR v_result.failed_order_id <> 'f5000000-0000-4000-8000-000000000009'
       OR v_result.failed_sqlstate <> 'P0001'
       OR v_result.failed_error_class <> 'unknown_failure'
       OR v_result.last_processed_order_id <> 'f5000000-0000-4000-8000-000000000008' THEN
        RAISE EXCEPTION 'backfill failure accounting/cursor is wrong: %', v_result;
    END IF;

    IF v_result::text LIKE '%forced backfill enqueue failure%' THEN
        RAISE EXCEPTION 'backfill returned raw PostgreSQL error text';
    END IF;

    IF pg_temp.work_count('f5000000-0000-4000-8000-000000000009') <> 0 THEN
        RAISE EXCEPTION 'failed backfill order has a work row';
    END IF;
    IF pg_temp.work_count('f5000000-0000-4000-8000-000000000010') <> 0 THEN
        RAISE EXCEPTION 'backfill advanced past a failed order';
    END IF;

    -- Removing the forced failure and retrying from last_processed must
    -- process the failed order, proving the cursor did not skip it.
    SELECT * INTO v_retry
      FROM system.backfill_reputation_stock_order_work(
          1, v_result.last_processed_order_id
      );
    IF v_retry.scanned_count <> 1
       OR v_retry.enqueued_count <> 1
       OR v_retry.existing_count <> 0
       OR v_retry.failed_count <> 0
       OR v_retry.last_processed_order_id <> 'f5000000-0000-4000-8000-000000000009' THEN
        RAISE EXCEPTION 'failed backfill order was not retryable: %', v_retry;
    END IF;
END;
$backfill_failure$;

DO $backfill_terminal$
DECLARE
    v_result record;
    v_status text;
    v_now timestamptz := clock_timestamp();
BEGIN
    PERFORM pg_temp.insert_producer_order(
        'f5000000-0000-4000-8000-000000000011', 'delivered', 'stock', clock_timestamp()
    );
    DELETE FROM reputation.processing_work
     WHERE source_reference = 'f5000000-0000-4000-8000-000000000011';
    INSERT INTO reputation.processing_work (
        work_kind, source_system, source_reference, status, attempt_count,
        max_attempts, next_attempt_at, dead_letter_reason_code,
        dead_lettered_at, created_at, updated_at
    ) VALUES (
        'stock_order_engagement_ingestion', 'vunio',
        'f5000000-0000-4000-8000-000000000011',
        'dead_letter', 1, 5, v_now,
        'fixture_terminal', v_now, v_now, v_now
    );

    SELECT * INTO v_result
      FROM system.backfill_reputation_stock_order_work(
          10, 'f5000000-0000-4000-8000-000000000010'
      );
    IF v_result.scanned_count <> 1
       OR v_result.enqueued_count <> 0
       OR v_result.existing_count <> 1
       OR v_result.failed_count <> 0
       OR v_result.last_processed_order_id <> 'f5000000-0000-4000-8000-000000000011' THEN
        RAISE EXCEPTION 'backfill terminal accounting is wrong: %', v_result;
    END IF;

    SELECT status INTO v_status
      FROM reputation.processing_work
     WHERE source_reference='f5000000-0000-4000-8000-000000000011';
    IF v_status <> 'dead_letter' THEN
        RAISE EXCEPTION 'backfill reopened terminal work';
    END IF;
END;
$backfill_terminal$;

DO $backfill_validation$
BEGIN
    BEGIN
        PERFORM system.backfill_reputation_stock_order_work(0, NULL);
        RAISE EXCEPTION 'backfill accepted limit 0';
    EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
    END;

    BEGIN
        PERFORM system.backfill_reputation_stock_order_work(501, NULL);
        RAISE EXCEPTION 'backfill accepted limit 501';
    EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
    END;
END;
$backfill_validation$;

ROLLBACK;
