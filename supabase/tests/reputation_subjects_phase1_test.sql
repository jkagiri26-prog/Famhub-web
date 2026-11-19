-- ============================================================================
-- reputation_subjects_phase1_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE test for the Phase 1 Reputation subjects
-- foundation.
--
-- Requires:
--   supabase/migrations/20261119000001_reputation_subjects.sql
--
-- Never run destructive parts against production.
-- ============================================================================
BEGIN;

-- ----------------------------------------------------------------------------
-- Fixtures
-- ----------------------------------------------------------------------------
INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES (
    'f0000000-0000-4000-8000-000000000001',
    'Reputation Test Country',
    'QT',
    'QTX',
    '9999',
    true
);

INSERT INTO core.locations (id, name, country_id, is_active)
VALUES (
    'f0000000-0000-4000-8000-000000000002',
    'Reputation Test Location',
    'f0000000-0000-4000-8000-000000000001',
    true
);

INSERT INTO core.units (id, name, symbol, unit_type)
VALUES (
    'f0000000-0000-4000-8000-000000000003',
    'reputation-test-kilogram',
    'kg',
    'mass'
);

-- The deployed users.profiles trigger calls core.ensure_entity_for_profile().
-- Use the trigger's supported service_role path for disposable profile
-- fixtures; do not bypass or disable the identity lifecycle.
SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', 'service_role', true),
    set_config('request.jwt.claims', '{"role":"service_role"}', true);

INSERT INTO users.profiles (
    id, first_name, country_id, is_active, account_status
)
VALUES
    ('f0000000-0000-4000-8000-000000000101', 'Reputation P1',
     'f0000000-0000-4000-8000-000000000001', true, 'active'),
    ('f0000000-0000-4000-8000-000000000102', 'Reputation P2',
     'f0000000-0000-4000-8000-000000000001', true, 'active'),
    ('f0000000-0000-4000-8000-000000000103', 'Reputation P3',
     'f0000000-0000-4000-8000-000000000001', true, 'active'),
    ('f0000000-0000-4000-8000-000000000104', 'Reputation P4',
     'f0000000-0000-4000-8000-000000000001', true, 'active'),
    ('f0000000-0000-4000-8000-000000000105', 'Reputation Deleted',
     'f0000000-0000-4000-8000-000000000001', true, 'active');

UPDATE users.profiles
SET deleted_at = clock_timestamp()
WHERE id = 'f0000000-0000-4000-8000-000000000105';

-- Clear the fixture-only privileged JWT context before behavior tests.
SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', '', true),
    set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active)
VALUES
    ('f0000000-0000-4000-8000-000000000201', 'Reputation Entity E1',
     'farm', 'f0000000-0000-4000-8000-000000000101', true),
    ('f0000000-0000-4000-8000-000000000203', 'Reputation Entity E3',
     'farm', 'f0000000-0000-4000-8000-000000000103', true);

INSERT INTO core.items (id, name)
VALUES
    ('f0000000-0000-4000-8000-000000000301', 'Reputation Item 1'),
    ('f0000000-0000-4000-8000-000000000302', 'Reputation Item 2'),
    ('f0000000-0000-4000-8000-000000000303', 'Reputation Item 3');

INSERT INTO core.item_variants (id, item_id, name)
VALUES
    ('f0000000-0000-4000-8000-000000000401',
     'f0000000-0000-4000-8000-000000000301', 'Reputation Variant 1'),
    ('f0000000-0000-4000-8000-000000000402',
     'f0000000-0000-4000-8000-000000000302', 'Reputation Variant 2');

INSERT INTO commerce.stock_registry (
    id, entity_id, variant_id, product_id, location_id, unit_id,
    quantity, reserved_quantity, status
)
VALUES (
    'f0000000-0000-4000-8000-000000000601',
    'f0000000-0000-4000-8000-000000000201',
    'f0000000-0000-4000-8000-000000000401',
    'f0000000-0000-4000-8000-000000000301',
    'f0000000-0000-4000-8000-000000000002',
    'f0000000-0000-4000-8000-000000000003',
    10, 0, 'active'
);

-- Use a stock-backed listing fixture so the test remains valid against the
-- deployed marketplace listing stock-integrity trigger. Reputation subject
-- registration is independent of whether the listing is standalone or
-- stock-backed.
INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency,
    location_id, variant_id, stock_id, quantity_offered, unit_id, status
)
VALUES (
    'f0000000-0000-4000-8000-000000000501',
    'f0000000-0000-4000-8000-000000000201',
    'Reputation Test Listing',
    100,
    'KES',
    'f0000000-0000-4000-8000-000000000002',
    'f0000000-0000-4000-8000-000000000401',
    'f0000000-0000-4000-8000-000000000601',
    NULL,
    'f0000000-0000-4000-8000-000000000003',
    'active'
);

-- ----------------------------------------------------------------------------
-- Valid registration and idempotency
-- ----------------------------------------------------------------------------
DO $valid$
DECLARE
    v_profile_farmer uuid;
    v_profile_person uuid;
    v_profile_seller uuid;
    v_entity_entity uuid;
    v_entity_seller uuid;
    v_listing uuid;
    v_item uuid;
    v_variant uuid;
    v_duplicate uuid;
BEGIN
    v_profile_farmer := reputation.register_subject(
        'profile', 'farmer', 'f0000000-0000-4000-8000-000000000101'
    );
    v_profile_person := reputation.register_subject(
        'profile', 'person', 'f0000000-0000-4000-8000-000000000101'
    );
    v_profile_seller := reputation.register_subject(
        'profile', 'seller', 'f0000000-0000-4000-8000-000000000102'
    );
    v_entity_entity := reputation.register_subject(
        'entity', 'entity', 'f0000000-0000-4000-8000-000000000201'
    );
    v_entity_seller := reputation.register_subject(
        'entity', 'seller', 'f0000000-0000-4000-8000-000000000201'
    );
    v_listing := reputation.register_subject(
        'listing', 'listing', 'f0000000-0000-4000-8000-000000000501'
    );
    v_item := reputation.register_subject(
        'item', 'product', 'f0000000-0000-4000-8000-000000000301'
    );
    v_variant := reputation.register_subject(
        'variant', 'product_variant', 'f0000000-0000-4000-8000-000000000401'
    );

    IF v_profile_farmer IS NULL OR v_profile_person IS NULL
       OR v_profile_seller IS NULL OR v_entity_entity IS NULL
       OR v_entity_seller IS NULL OR v_listing IS NULL
       OR v_item IS NULL OR v_variant IS NULL THEN
        RAISE EXCEPTION 'one or more valid subject registrations returned NULL';
    END IF;

    IF (SELECT count(*) FROM reputation.subjects) <> 8 THEN
        RAISE EXCEPTION 'expected exactly eight valid subject rows';
    END IF;

    v_duplicate := reputation.register_subject(
        'profile', 'farmer', 'f0000000-0000-4000-8000-000000000101'
    );
    IF v_duplicate <> v_profile_farmer THEN
        RAISE EXCEPTION 'active duplicate registration did not return the existing ID';
    END IF;
    IF (SELECT count(*) FROM reputation.subjects WHERE subject_type = 'profile'
        AND subject_role = 'farmer'
        AND profile_id = 'f0000000-0000-4000-8000-000000000101') <> 1 THEN
        RAISE EXCEPTION 'active duplicate registration created a second row';
    END IF;
END;
$valid$;

-- ----------------------------------------------------------------------------
-- Invalid registration
-- ----------------------------------------------------------------------------
DO $invalid$
BEGIN
    BEGIN
        PERFORM reputation.register_subject(
            'profile', 'farmer', 'f0000000-0000-4000-8000-000000000201'
        );
        RAISE EXCEPTION 'expected wrong type/identity registration failure';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected wrong type/identity registration failure' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        PERFORM reputation.register_subject(
            'entity', 'product', 'f0000000-0000-4000-8000-000000000201'
        );
        RAISE EXCEPTION 'expected wrong role/type registration failure';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected wrong role/type registration failure' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        PERFORM reputation.register_subject(
            'listing', 'listing', 'f0000000-0000-4000-8000-000000000999'
        );
        RAISE EXCEPTION 'expected nonexistent canonical identity failure';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected nonexistent canonical identity failure' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        PERFORM reputation.register_subject(
            'profile', 'person', 'f0000000-0000-4000-8000-000000000105'
        );
        RAISE EXCEPTION 'expected soft-deleted profile failure';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected soft-deleted profile failure' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        PERFORM reputation.register_subject(
            'business_profile', 'seller', 'f0000000-0000-4000-8000-000000000999'
        );
        RAISE EXCEPTION 'expected business_profile rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected business_profile rejection' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        PERFORM reputation.register_subject(
            'service', 'service', 'f0000000-0000-4000-8000-000000000999'
        );
        RAISE EXCEPTION 'expected service rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected service rejection' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        PERFORM reputation.register_subject(
            'extension_provider', 'extension_provider',
            'f0000000-0000-4000-8000-000000000999'
        );
        RAISE EXCEPTION 'expected extension-provider rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected extension-provider rejection' THEN
            RAISE;
        END IF;
    END;
END;
$invalid$;

-- Constraint-level invalid identities/roles.
DO $table_constraints$
BEGIN
    BEGIN
        INSERT INTO reputation.subjects (subject_type, subject_role)
        VALUES ('profile', 'farmer');
        RAISE EXCEPTION 'expected zero-identity rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected zero-identity rejection' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        INSERT INTO reputation.subjects (subject_type, subject_role, profile_id, entity_id)
        VALUES (
            'profile', 'farmer',
            'f0000000-0000-4000-8000-000000000101',
            'f0000000-0000-4000-8000-000000000201'
        );
        RAISE EXCEPTION 'expected multiple-identity rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected multiple-identity rejection' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        INSERT INTO reputation.subjects (subject_type, subject_role, entity_id)
        VALUES ('item', 'product', 'f0000000-0000-4000-8000-000000000201');
        RAISE EXCEPTION 'expected type/identity mismatch rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected type/identity mismatch rejection' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        INSERT INTO reputation.subjects (subject_type, subject_role, entity_id)
        VALUES ('entity', 'product', 'f0000000-0000-4000-8000-000000000201');
        RAISE EXCEPTION 'expected role/type mismatch rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected role/type mismatch rejection' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        INSERT INTO reputation.subjects (subject_type, subject_role, profile_id)
        VALUES (
            'profile', 'farmer',
            'f0000000-0000-4000-8000-000000000101'
        );
        RAISE EXCEPTION 'expected duplicate identity/role rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected duplicate identity/role rejection' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        INSERT INTO reputation.subjects (subject_type, subject_role, profile_id)
        VALUES (
            'profile', 'farmer',
            'f0000000-0000-4000-8000-000000000999'
        );
        RAISE EXCEPTION 'expected canonical FK rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected canonical FK rejection' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        INSERT INTO reputation.subjects (
            subject_type, subject_role, profile_id, status, retired_at
        )
        VALUES (
            'profile', 'person',
            'f0000000-0000-4000-8000-000000000103',
            'active', clock_timestamp()
        );
        RAISE EXCEPTION 'expected active/retired_at rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected active/retired_at rejection' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        INSERT INTO reputation.subjects (
            subject_type, subject_role, profile_id, status, retired_at
        )
        VALUES (
            'profile', 'person',
            'f0000000-0000-4000-8000-000000000104',
            'retired', NULL
        );
        RAISE EXCEPTION 'expected retired/retired_at rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected retired/retired_at rejection' THEN
            RAISE;
        END IF;
    END;
END;
$table_constraints$;

-- ----------------------------------------------------------------------------
-- Lifecycle and immutability
-- ----------------------------------------------------------------------------
DO $lifecycle$
DECLARE
    v_farmer uuid;
    v_seller uuid;
    v_sql text;
BEGIN
    SELECT id INTO v_farmer
    FROM reputation.subjects
    WHERE subject_type = 'profile' AND subject_role = 'farmer'
      AND profile_id = 'f0000000-0000-4000-8000-000000000101';

    SELECT id INTO v_seller
    FROM reputation.subjects
    WHERE subject_type = 'profile' AND subject_role = 'seller'
      AND profile_id = 'f0000000-0000-4000-8000-000000000102';

    IF v_farmer IS NULL OR v_seller IS NULL THEN
        RAISE EXCEPTION 'expected lifecycle subjects are missing';
    END IF;

    IF (SELECT status FROM reputation.subjects WHERE id = v_farmer) <> 'active'
       OR (SELECT retired_at FROM reputation.subjects WHERE id = v_farmer) IS NOT NULL THEN
        RAISE EXCEPTION 'new subject is not active with NULL retired_at';
    END IF;

    PERFORM reputation.retire_subject(v_seller);
    IF (SELECT status FROM reputation.subjects WHERE id = v_seller) <> 'retired'
       OR (SELECT retired_at FROM reputation.subjects WHERE id = v_seller) IS NULL
       OR (SELECT profile_id FROM reputation.subjects WHERE id = v_seller)
            IS DISTINCT FROM 'f0000000-0000-4000-8000-000000000102' THEN
        RAISE EXCEPTION 'retirement did not set state or preserve identity';
    END IF;

    PERFORM reputation.retire_subject(v_seller);
    IF (SELECT status FROM reputation.subjects WHERE id = v_seller) <> 'retired' THEN
        RAISE EXCEPTION 'repeated retirement changed state';
    END IF;

    BEGIN
        UPDATE reputation.subjects
        SET status = 'active', retired_at = NULL
        WHERE id = v_seller;
        RAISE EXCEPTION 'expected retired->active rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected retired->active rejection' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        UPDATE reputation.subjects
        SET retired_at = clock_timestamp()
        WHERE id = v_seller;
        RAISE EXCEPTION 'expected retired_at rewrite rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected retired_at rewrite rejection' THEN
            RAISE;
        END IF;
    END;

    IF (SELECT status FROM reputation.subjects WHERE id = v_seller) <> 'retired'
       OR (SELECT retired_at FROM reputation.subjects WHERE id = v_seller) IS NULL THEN
        RAISE EXCEPTION 'invalid lifecycle update changed retired subject';
    END IF;

    BEGIN
        PERFORM reputation.register_subject(
            'profile', 'seller', 'f0000000-0000-4000-8000-000000000102'
        );
        RAISE EXCEPTION 'expected retired registration rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected retired registration rejection' THEN
            RAISE;
        END IF;
    END;

    FOREACH v_sql IN ARRAY ARRAY[
        format('UPDATE reputation.subjects SET id = %L WHERE id = %L',
            gen_random_uuid(), v_farmer),
        format('UPDATE reputation.subjects SET subject_type = ''entity'' WHERE id = %L',
            v_farmer),
        format('UPDATE reputation.subjects SET subject_role = ''person'' WHERE id = %L',
            v_farmer),
        format('UPDATE reputation.subjects SET profile_id = %L WHERE id = %L',
            'f0000000-0000-4000-8000-000000000102', v_farmer),
        format('UPDATE reputation.subjects SET entity_id = %L WHERE id = %L',
            'f0000000-0000-4000-8000-000000000201', v_farmer),
        format('UPDATE reputation.subjects SET listing_id = %L WHERE id = %L',
            'f0000000-0000-4000-8000-000000000501', v_farmer),
        format('UPDATE reputation.subjects SET item_id = %L WHERE id = %L',
            'f0000000-0000-4000-8000-000000000301', v_farmer),
        format('UPDATE reputation.subjects SET variant_id = %L WHERE id = %L',
            'f0000000-0000-4000-8000-000000000401', v_farmer),
        format('UPDATE reputation.subjects SET created_at = clock_timestamp() WHERE id = %L',
            v_farmer)
    ]
    LOOP
        BEGIN
            EXECUTE v_sql;
            RAISE EXCEPTION 'expected identity immutability rejection';
        EXCEPTION WHEN OTHERS THEN
            IF SQLERRM = 'expected identity immutability rejection' THEN
                RAISE;
            END IF;
        END;
    END LOOP;

    BEGIN
        DELETE FROM reputation.subjects WHERE id = v_farmer;
        RAISE EXCEPTION 'expected subject deletion rejection';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected subject deletion rejection' THEN
            RAISE;
        END IF;
    END;
END;
$lifecycle$;

-- ----------------------------------------------------------------------------
-- Security ACL boundary
-- ----------------------------------------------------------------------------
DO $security$
DECLARE
    v_register oid := to_regprocedure('reputation.register_subject(text,text,uuid)');
    v_retire oid := to_regprocedure('reputation.retire_subject(uuid)');
    v_guard oid := to_regprocedure('reputation.guard_subject_identity()');
    v_delete_guard oid := to_regprocedure('reputation.prevent_subject_delete()');
BEGIN
    IF NOT has_schema_privilege('service_role', 'reputation', 'USAGE') THEN
        RAISE EXCEPTION 'service_role lacks schema usage';
    END IF;
    IF has_schema_privilege('anon', 'reputation', 'USAGE')
       OR has_schema_privilege('authenticated', 'reputation', 'USAGE') THEN
        RAISE EXCEPTION 'browser role has schema usage';
    END IF;

    IF has_schema_privilege('anon', 'reputation', 'CREATE')
       OR has_schema_privilege('authenticated', 'reputation', 'CREATE')
       OR has_schema_privilege('service_role', 'reputation', 'CREATE') THEN
        RAISE EXCEPTION 'unexpected schema CREATE privilege';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_namespace n
        CROSS JOIN LATERAL aclexplode(
            COALESCE(n.nspacl, acldefault('n', n.nspowner))
        ) a
        WHERE n.nspname = 'reputation'
          AND a.grantee = 0
    ) THEN
        RAISE EXCEPTION 'PUBLIC has Reputation schema privileges';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        CROSS JOIN LATERAL aclexplode(
            COALESCE(c.relacl, acldefault('r', c.relowner))
        ) a
        WHERE n.nspname = 'reputation'
          AND c.relname = 'subjects'
          AND a.grantee = 0
    ) THEN
        RAISE EXCEPTION 'PUBLIC has direct reputation.subjects privileges';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        CROSS JOIN LATERAL aclexplode(
            COALESCE(p.proacl, acldefault('f', p.proowner))
        ) a
        WHERE n.nspname = 'reputation'
          AND p.proname IN (
              'register_subject',
              'retire_subject',
              'guard_subject_identity',
              'prevent_subject_delete'
          )
          AND a.grantee = 0
    ) THEN
        RAISE EXCEPTION 'PUBLIC has Reputation function execution privilege';
    END IF;

    IF has_table_privilege('anon', 'reputation.subjects', 'SELECT')
       OR has_table_privilege('authenticated', 'reputation.subjects', 'SELECT')
       OR has_table_privilege('service_role', 'reputation.subjects', 'SELECT') THEN
        RAISE EXCEPTION 'direct subject SELECT privilege exists';
    END IF;
    IF has_table_privilege('anon', 'reputation.subjects', 'INSERT')
       OR has_table_privilege('authenticated', 'reputation.subjects', 'INSERT')
       OR has_table_privilege('service_role', 'reputation.subjects', 'INSERT') THEN
        RAISE EXCEPTION 'direct subject INSERT privilege exists';
    END IF;
    IF has_table_privilege('anon', 'reputation.subjects', 'UPDATE')
       OR has_table_privilege('authenticated', 'reputation.subjects', 'UPDATE')
       OR has_table_privilege('service_role', 'reputation.subjects', 'UPDATE') THEN
        RAISE EXCEPTION 'direct subject UPDATE privilege exists';
    END IF;
    IF has_table_privilege('anon', 'reputation.subjects', 'DELETE')
       OR has_table_privilege('authenticated', 'reputation.subjects', 'DELETE')
       OR has_table_privilege('service_role', 'reputation.subjects', 'DELETE') THEN
        RAISE EXCEPTION 'direct subject DELETE privilege exists';
    END IF;

    IF NOT has_function_privilege('service_role', v_register, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_retire, 'EXECUTE') THEN
        RAISE EXCEPTION 'service_role cannot execute trusted lifecycle functions';
    END IF;
    IF has_function_privilege('anon', v_register, 'EXECUTE')
       OR has_function_privilege('authenticated', v_register, 'EXECUTE')
       OR has_function_privilege('anon', v_retire, 'EXECUTE')
       OR has_function_privilege('authenticated', v_retire, 'EXECUTE') THEN
        RAISE EXCEPTION 'browser role can execute trusted lifecycle functions';
    END IF;
    IF has_function_privilege('service_role', v_guard, 'EXECUTE')
       OR has_function_privilege('service_role', v_delete_guard, 'EXECUTE') THEN
        RAISE EXCEPTION 'trigger function is directly executable';
    END IF;
END;
$security$;

-- ----------------------------------------------------------------------------
-- Actual role behavior — disposable database only.
--
-- The test session must be able to SET ROLE (local disposable DB). These
-- checks deliberately execute as anon/authenticated/service_role instead of
-- relying only on has_* ACL metadata. Never run this file against production.
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;
DO $anon_role$
BEGIN
    BEGIN
        PERFORM reputation.register_subject(
            'profile', 'person', 'f0000000-0000-4000-8000-000000000103'
        );
        RAISE EXCEPTION 'anon register unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        PERFORM reputation.retire_subject(
            'f0000000-0000-4000-8000-000000000103'
        );
        RAISE EXCEPTION 'anon retire unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        PERFORM count(*) FROM reputation.subjects;
        RAISE EXCEPTION 'anon direct SELECT unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        INSERT INTO reputation.subjects (subject_type, subject_role, profile_id)
        VALUES ('profile', 'person', 'f0000000-0000-4000-8000-000000000103');
        RAISE EXCEPTION 'anon direct INSERT unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        UPDATE reputation.subjects SET status = 'retired'
        WHERE id = 'f0000000-0000-4000-8000-000000000103';
        RAISE EXCEPTION 'anon direct UPDATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM reputation.subjects
        WHERE id = 'f0000000-0000-4000-8000-000000000103';
        RAISE EXCEPTION 'anon direct DELETE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$anon_role$;
RESET ROLE;

SET LOCAL ROLE authenticated;
DO $auth_role$
BEGIN
    BEGIN
        PERFORM reputation.register_subject(
            'profile', 'person', 'f0000000-0000-4000-8000-000000000103'
        );
        RAISE EXCEPTION 'authenticated register unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        PERFORM reputation.retire_subject(
            'f0000000-0000-4000-8000-000000000103'
        );
        RAISE EXCEPTION 'authenticated retire unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        PERFORM count(*) FROM reputation.subjects;
        RAISE EXCEPTION 'authenticated direct SELECT unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        INSERT INTO reputation.subjects (subject_type, subject_role, profile_id)
        VALUES ('profile', 'person', 'f0000000-0000-4000-8000-000000000103');
        RAISE EXCEPTION 'authenticated direct INSERT unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        UPDATE reputation.subjects SET status = 'retired'
        WHERE id = 'f0000000-0000-4000-8000-000000000103';
        RAISE EXCEPTION 'authenticated direct UPDATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM reputation.subjects
        WHERE id = 'f0000000-0000-4000-8000-000000000103';
        RAISE EXCEPTION 'authenticated direct DELETE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$auth_role$;
RESET ROLE;

SET LOCAL ROLE service_role;
DO $service_role$
DECLARE
    v_subject_id uuid;
BEGIN
    v_subject_id := reputation.register_subject(
        'profile', 'person', 'f0000000-0000-4000-8000-000000000103'
    );
    IF v_subject_id IS NULL THEN
        RAISE EXCEPTION 'service_role registration returned NULL';
    END IF;

    PERFORM set_config(
        'reputation.test_service_subject_id',
        v_subject_id::text,
        true
    );

    BEGIN
        INSERT INTO reputation.subjects (subject_type, subject_role, profile_id)
        VALUES ('profile', 'person', 'f0000000-0000-4000-8000-000000000103');
        RAISE EXCEPTION 'service_role direct INSERT unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        UPDATE reputation.subjects SET status = 'retired'
        WHERE id = v_subject_id;
        RAISE EXCEPTION 'service_role direct UPDATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM reputation.subjects
        WHERE id = v_subject_id;
        RAISE EXCEPTION 'service_role direct DELETE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    PERFORM reputation.retire_subject(v_subject_id);
END;
$service_role$;
RESET ROLE;

DO $service_verify$
DECLARE
    v_subject_id uuid := current_setting(
        'reputation.test_service_subject_id'
    )::uuid;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM reputation.subjects
        WHERE id = v_subject_id
          AND status = 'retired'
          AND retired_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'service_role lifecycle execution did not retire subject';
    END IF;
END;
$service_verify$;

-- ----------------------------------------------------------------------------
-- FK retention / existing variant cascade boundary
-- ----------------------------------------------------------------------------
DO $retention$
BEGIN
    PERFORM reputation.register_subject(
        'profile', 'person', 'f0000000-0000-4000-8000-000000000104'
    );
    BEGIN
        DELETE FROM users.profiles
        WHERE id = 'f0000000-0000-4000-8000-000000000104';
        RAISE EXCEPTION 'expected profile delete restriction';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected profile delete restriction' OR SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
    END;

    PERFORM reputation.register_subject(
        'entity', 'entity', 'f0000000-0000-4000-8000-000000000203'
    );
    BEGIN
        DELETE FROM core.entities
        WHERE id = 'f0000000-0000-4000-8000-000000000203';
        RAISE EXCEPTION 'expected entity delete restriction';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected entity delete restriction' OR SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
    END;

    PERFORM reputation.register_subject(
        'listing', 'listing', 'f0000000-0000-4000-8000-000000000501'
    );
    BEGIN
        DELETE FROM marketplace.listings
        WHERE id = 'f0000000-0000-4000-8000-000000000501';
        RAISE EXCEPTION 'expected listing delete restriction';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected listing delete restriction' OR SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
    END;

    PERFORM reputation.register_subject(
        'item', 'product', 'f0000000-0000-4000-8000-000000000303'
    );
    BEGIN
        DELETE FROM core.items
        WHERE id = 'f0000000-0000-4000-8000-000000000303';
        RAISE EXCEPTION 'expected direct item delete restriction';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected direct item delete restriction' OR SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
    END;

    PERFORM reputation.register_subject(
        'variant', 'product_variant', 'f0000000-0000-4000-8000-000000000402'
    );
    BEGIN
        DELETE FROM core.item_variants
        WHERE id = 'f0000000-0000-4000-8000-000000000402';
        RAISE EXCEPTION 'expected direct variant delete restriction';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected direct variant delete restriction' OR SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
    END;

    BEGIN
        DELETE FROM core.items
        WHERE id = 'f0000000-0000-4000-8000-000000000302';
        RAISE EXCEPTION 'expected item/variant cascade restriction';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'expected item/variant cascade restriction' OR SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
    END;
END;
$retention$;

-- ----------------------------------------------------------------------------
-- Structural isolation and exact Phase 1 shape
-- ----------------------------------------------------------------------------
DO $structure$
DECLARE
    v_columns text[];
    v_function_names text[];
    v_table_count integer;
    v_rls boolean;
BEGIN
    SELECT count(*) INTO v_table_count
    FROM pg_tables
    WHERE schemaname = 'reputation';
    IF v_table_count <> 1 THEN
        RAISE EXCEPTION 'Phase 1 must contain exactly one Reputation table';
    END IF;

    SELECT array_agg(column_name::text ORDER BY ordinal_position)
      INTO v_columns
      FROM information_schema.columns
     WHERE table_schema = 'reputation' AND table_name = 'subjects';

    IF v_columns IS DISTINCT FROM ARRAY[
        'id', 'subject_type', 'subject_role', 'profile_id', 'entity_id',
        'listing_id', 'item_id', 'variant_id', 'status', 'created_at',
        'updated_at', 'retired_at'
    ]::text[] THEN
        RAISE EXCEPTION 'reputation.subjects columns do not match Phase 1';
    END IF;

    SELECT array_agg(proname::text ORDER BY proname)
      INTO v_function_names
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'reputation';

    IF v_function_names IS DISTINCT FROM ARRAY[
        'guard_subject_identity',
        'prevent_subject_delete',
        'register_subject',
        'retire_subject'
    ]::text[] THEN
        RAISE EXCEPTION 'unexpected Reputation function inventory';
    END IF;

    IF to_regclass('reputation.reviews') IS NOT NULL
       OR to_regclass('reputation.engagements') IS NOT NULL
       OR to_regclass('reputation.review_eligibility') IS NOT NULL
       OR to_regclass('reputation.review_responses') IS NOT NULL
       OR to_regclass('reputation.subject_rating_summaries') IS NOT NULL
       OR to_regclass('reputation.subject_relations') IS NOT NULL THEN
        RAISE EXCEPTION 'out-of-scope Reputation object exists';
    END IF;

    IF to_regprocedure('reputation.get_public_subject_reputation(text,uuid,text)') IS NOT NULL
       OR to_regprocedure('reputation.list_public_reviews(text,uuid,text)') IS NOT NULL THEN
        RAISE EXCEPTION 'unexpected public Reputation read interface exists';
    END IF;

    SELECT relrowsecurity INTO v_rls
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'reputation' AND c.relname = 'subjects';
    IF v_rls IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'reputation.subjects RLS is not enabled';
    END IF;

    IF (SELECT column_default FROM information_schema.columns
        WHERE table_schema = 'reputation' AND table_name = 'subjects'
          AND column_name = 'id') NOT LIKE '%uuid_generate_v7%' THEN
        RAISE EXCEPTION 'Reputation subject ID is not using uuid_generate_v7';
    END IF;

    IF (
        SELECT count(*)
        FROM pg_constraint
        WHERE conrelid = 'reputation.subjects'::regclass
          AND conname IN (
              'reputation_subjects_profile_id_fkey',
              'reputation_subjects_entity_id_fkey',
              'reputation_subjects_listing_id_fkey',
              'reputation_subjects_item_id_fkey',
              'reputation_subjects_variant_id_fkey'
          )
          AND confdeltype = 'r'
    ) <> 5 THEN
        RAISE EXCEPTION 'expected five canonical RESTRICT foreign keys';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'commerce' AND table_name = 'business_profiles'
          AND column_name = 'rating'
    ) THEN
        RAISE EXCEPTION 'legacy business profile rating column unexpectedly absent';
    END IF;
END;
$structure$;

ROLLBACK;
