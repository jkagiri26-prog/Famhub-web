-- ============================================================================
-- reputation_engagement_ingestion_concurrency_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE concurrency test for Phase 2C-1 ingestion.
--
-- Uses committed disposable fixtures because dblink sessions require visibility
-- across connections. Run only against a disposable local database and discard
-- the database afterward. Never run against production.
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS dblink;

BEGIN;

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('90000000-0000-4000-8000-000000000001', 'Ingestion Concurrency Country', 'IQ', 'IQT', '9994', true);
INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('90000000-0000-4000-8000-000000000002', 'Ingestion Concurrency Location',
        '90000000-0000-4000-8000-000000000001', true);
INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('90000000-0000-4000-8000-000000000003', 'ingestion-concurrency-kilogram', 'kg', 'mass');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', 'service_role', true),
    set_config('request.jwt.claims', '{"role":"service_role"}', true);
INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
    ('91000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000901',
     'Ingestion Concurrency Buyer', '90000000-0000-4000-8000-000000000001', true, 'active'),
    ('91000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000902',
     'Ingestion Concurrency Seller', '90000000-0000-4000-8000-000000000001', true, 'active');
SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', '', true),
    set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, verification_status)
VALUES
    ('92000000-0000-4000-8000-000000000001', 'Ingestion Concurrency Buyer Entity',
     'individual_pro', '91000000-0000-4000-8000-000000000001', true, 'verified'),
    ('92000000-0000-4000-8000-000000000002', 'Ingestion Concurrency Seller Entity',
     'farm', '91000000-0000-4000-8000-000000000002', true, 'verified');

INSERT INTO core.items (id, name)
VALUES ('93000000-0000-4000-8000-000000000001', 'Ingestion Concurrency Item');
INSERT INTO core.item_variants (id, item_id, name)
VALUES ('93000000-0000-4000-8000-000000000002',
        '93000000-0000-4000-8000-000000000001', 'Ingestion Concurrency Variant');

INSERT INTO commerce.stock_registry (
    id, entity_id, business_profile_id, variant_id, product_id, location_id,
    quantity, reserved_quantity, unit_id, status
) VALUES (
    '93000000-0000-4000-8000-000000000004',
    '92000000-0000-4000-8000-000000000002',
    '94000000-0000-4000-8000-000000000001',
    '93000000-0000-4000-8000-000000000002',
    '93000000-0000-4000-8000-000000000001',
    '90000000-0000-4000-8000-000000000002',
    1000.00, 0.00, '90000000-0000-4000-8000-000000000003', 'active'
);

INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status, stock_id
) VALUES (
    '93000000-0000-4000-8000-000000000003',
    '92000000-0000-4000-8000-000000000002',
    'Ingestion Concurrency Listing', 50.00, 'KES',
    '90000000-0000-4000-8000-000000000002',
    '93000000-0000-4000-8000-000000000002',
    1000.00, '90000000-0000-4000-8000-000000000003', 'active',
    '93000000-0000-4000-8000-000000000004'
);

INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES (
    '94000000-0000-4000-8000-000000000001', 'farm',
    '91000000-0000-4000-8000-000000000002', 'Ingestion Concurrency Supplier',
    'verified', true, '92000000-0000-4000-8000-000000000002', true
);

INSERT INTO commerce.orders (
    id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
    payment_status, order_date, delivered_at, delivery_date, entity_id,
    order_kind, buyer_entity_id, seller_entity_id, currency, unit_id,
    status_changed_by_profile_id
) VALUES (
    '95000000-0000-4000-8000-000000000001',
    '91000000-0000-4000-8000-000000000001',
    '93000000-0000-4000-8000-000000000003',
    '94000000-0000-4000-8000-000000000001',
    2.00, 100.00, 'delivered', 'pending',
    '2026-11-20T09:00:00Z', '2026-11-20T10:00:00Z', '2026-11-20T10:00:00Z',
    '92000000-0000-4000-8000-000000000002', 'stock',
    '92000000-0000-4000-8000-000000000001',
    '92000000-0000-4000-8000-000000000002', 'KES',
    '90000000-0000-4000-8000-000000000003',
    '91000000-0000-4000-8000-000000000001'
);

INSERT INTO commerce.order_items (
    id, order_id, listing_id, product_id, quantity, unit, price_per_unit,
    stock_id, variant_id, unit_id
) VALUES
    ('96000000-0000-4000-8000-000000000001',
     '95000000-0000-4000-8000-000000000001',
     '93000000-0000-4000-8000-000000000003',
     '93000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00,
     '93000000-0000-4000-8000-000000000004',
     '93000000-0000-4000-8000-000000000002',
     '90000000-0000-4000-8000-000000000003'),
    ('96000000-0000-4000-8000-000000000002',
     '95000000-0000-4000-8000-000000000001',
     '93000000-0000-4000-8000-000000000003',
     '93000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00,
     '93000000-0000-4000-8000-000000000004',
     '93000000-0000-4000-8000-000000000002',
     '90000000-0000-4000-8000-000000000003');

COMMIT;

DO $connect$
DECLARE
    v_conn text;
BEGIN
    SELECT format('host=%s port=%s dbname=%s user=%s',
                  split_part(setting, ',', 1),
                  current_setting('port'),
                  current_database(),
                  current_user)
      INTO v_conn
      FROM pg_settings
     WHERE name = 'unix_socket_directories';

    PERFORM dblink_connect('ingest_a', v_conn);
    PERFORM dblink_connect('ingest_b', v_conn);
END;
$connect$;

DO $install$
DECLARE
    v_sql text := $fn$
CREATE FUNCTION pg_temp.try_ingest(p_order uuid)
RETURNS text
LANGUAGE plpgsql
AS $body$
DECLARE
    r record;
BEGIN
    SELECT * INTO r
      FROM system.ingest_reputation_stock_order_engagement(p_order);
    RETURN r.engagement_id::text || '|' || r.outcome || '|'
        || COALESCE(r.reason_code, '');
END;
$body$;
$fn$;
BEGIN
    PERFORM dblink_exec('ingest_a', v_sql);
    PERFORM dblink_exec('ingest_b', v_sql);
END;
$install$;

DO $concurrent$
DECLARE
    v_a text;
    v_b text;
    v_count integer;
    v_engagement_id uuid;
BEGIN
    PERFORM dblink_exec('ingest_a', 'BEGIN');
    PERFORM dblink_exec('ingest_b', 'BEGIN');

    PERFORM dblink_send_query(
        'ingest_a',
        $q$SELECT pg_temp.try_ingest('95000000-0000-4000-8000-000000000001'::uuid)$q$
    );
    PERFORM pg_sleep(0.3);
    PERFORM dblink_send_query(
        'ingest_b',
        $q$SELECT pg_temp.try_ingest('95000000-0000-4000-8000-000000000001'::uuid)$q$
    );
    PERFORM pg_sleep(0.3);

    SELECT result INTO v_a
      FROM dblink_get_result('ingest_a') AS t(result text);
    PERFORM result FROM dblink_get_result('ingest_a') AS t(result text);
    PERFORM dblink_exec('ingest_a', 'COMMIT');

    SELECT result INTO v_b
      FROM dblink_get_result('ingest_b') AS t(result text);
    PERFORM result FROM dblink_get_result('ingest_b') AS t(result text);
    PERFORM dblink_exec('ingest_b', 'COMMIT');

    IF NOT (
        (split_part(v_a, '|', 2) = 'created'
         AND split_part(v_b, '|', 2) = 'already_ingested')
        OR
        (split_part(v_a, '|', 2) = 'already_ingested'
         AND split_part(v_b, '|', 2) = 'created')
    ) THEN
        RAISE EXCEPTION 'unexpected concurrent ingestion results: % / %', v_a, v_b;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.engagements
     WHERE commerce_order_id = '95000000-0000-4000-8000-000000000001';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'concurrent ingestion created % engagements', v_count;
    END IF;

    SELECT id INTO v_engagement_id
      FROM reputation.engagements
     WHERE commerce_order_id = '95000000-0000-4000-8000-000000000001';

    SELECT count(*) INTO v_count
      FROM reputation.engagement_participants
     WHERE engagement_id = v_engagement_id;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'concurrent ingestion created % participants', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.engagement_subjects
     WHERE engagement_id = v_engagement_id;
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'concurrent ingestion created % subjects', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.engagement_events
     WHERE engagement_id = v_engagement_id
       AND event_type = 'engagement_recorded';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'concurrent ingestion created % engagement_recorded events', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.engagement_events
     WHERE engagement_id = v_engagement_id
       AND event_type = 'order_delivered';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'concurrent ingestion created % order_delivered events', v_count;
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.engagement_events
     WHERE engagement_id = v_engagement_id;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'concurrent ingestion created % total events', v_count;
    END IF;
END;
$concurrent$;

SELECT dblink_disconnect('ingest_b');
SELECT dblink_disconnect('ingest_a');

-- Committed disposable fixture is intentionally left for inspection. Discard
-- the local database after this test.
