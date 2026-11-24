-- ============================================================================
-- marketplace_public_seller_identity_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE test for the public seller identity RPC.
-- Requires 20261124000001_marketplace_public_seller_identity.sql and
-- 20261124000002_marketplace_public_seller_authorized_manager.sql.
-- ============================================================================
BEGIN;

DO $functions$
DECLARE
    v_function oid := to_regprocedure(
        'marketplace.get_public_listing_sellers(uuid[])'
    );
BEGIN
    IF v_function IS NULL THEN
        RAISE EXCEPTION 'public seller identity function is missing';
    END IF;

    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_function) THEN
        RAISE EXCEPTION 'public seller identity function must be SECURITY DEFINER';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE oid = v_function
          AND proconfig @> ARRAY[
            'search_path=pg_catalog, core, users, marketplace, commerce'
          ]
    ) THEN
        RAISE EXCEPTION 'public seller identity search_path is not pinned';
    END IF;

    IF NOT has_function_privilege('anon', v_function, 'EXECUTE')
       OR NOT has_function_privilege('authenticated', v_function, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_function, 'EXECUTE') THEN
        RAISE EXCEPTION 'public seller identity EXECUTE grants are incomplete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM aclexplode(
            (SELECT proacl FROM pg_proc WHERE oid = v_function)
        ) AS acl
        WHERE acl.grantee = 0
          AND acl.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'PUBLIC can execute public seller identity function';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM unnest(
            (SELECT proargnames FROM pg_proc WHERE oid = v_function)
        ) AS name
        WHERE name IN (
            'phone', 'email', 'auth_user_id', 'middle_name', 'last_name',
            'full_name', 'contact_phone', 'contact_email'
        )
    ) THEN
        RAISE EXCEPTION 'public seller identity exposes private fields';
    END IF;
END;
$functions$;

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('e9000000-0000-4000-8000-000000000001', 'Seller Identity Country', 'QI', 'QIX', '9911', true);

INSERT INTO core.locations (id, name, country_id, is_active)
VALUES
    ('e9000000-0000-4000-8000-000000000011', 'Seller Identity Location A',
     'e9000000-0000-4000-8000-000000000001', true),
    ('e9000000-0000-4000-8000-000000000012', 'Seller Identity Location B',
     'e9000000-0000-4000-8000-000000000001', true);

INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('e9000000-0000-4000-8000-000000000021', 'seller-identity-kg', 'kg', 'mass');

INSERT INTO users.profiles (
    id, auth_user_id, first_name, middle_name, last_name, email, phone,
    country_id, is_active, account_status
) VALUES
    ('e9000000-0000-4000-8000-000000000101',
     'e9000000-0000-4000-8000-000000000901',
     'James', 'Canonical', 'Kamau', 'james.private@example.test', '+254700000001',
     'e9000000-0000-4000-8000-000000000001', true, 'active'),
    ('e9000000-0000-4000-8000-000000000102',
     'e9000000-0000-4000-8000-000000000902',
     'Alice', 'Canonical', 'Wanjiku', 'alice.private@example.test', '+254700000002',
     'e9000000-0000-4000-8000-000000000001', true, 'active'),
    ('e9000000-0000-4000-8000-000000000103',
     'e9000000-0000-4000-8000-000000000903',
     'Mary', 'Canonical', 'Wambui', 'mary.private@example.test', '+254700000003',
     'e9000000-0000-4000-8000-000000000001', true, 'active');

INSERT INTO core.entities (
    id, name, entity_type, owner_id, primary_contact_profile_id, is_active,
    verification_status
) VALUES
    ('e9000000-0000-4000-8000-000000000201', 'JK Agrovet', 'agrovet',
     'e9000000-0000-4000-8000-000000000101',
     'e9000000-0000-4000-8000-000000000101', true, 'verified'),
    ('e9000000-0000-4000-8000-000000000202', 'Entity for Alice', 'individual_pro',
     'e9000000-0000-4000-8000-000000000102',
     'e9000000-0000-4000-8000-000000000102', true, 'verified'),
    ('e9000000-0000-4000-8000-000000000203', 'Acme Trading', 'trading_company',
     'e9000000-0000-4000-8000-000000000101',
     'e9000000-0000-4000-8000-000000000103', true, 'verified'),
    ('e9000000-0000-4000-8000-000000000204', 'Coop Without Manager', 'cooperative',
     'e9000000-0000-4000-8000-000000000101',
     'e9000000-0000-4000-8000-000000000101', true, 'verified');

INSERT INTO core.user_roles (id, name, type, is_active)
VALUES
    ('e9000000-0000-4000-8000-000000000701', 'Owner', 'commerce', true),
    ('e9000000-0000-4000-8000-000000000702', 'Manager', 'commerce', true)
ON CONFLICT (name) DO NOTHING;

INSERT INTO core.entity_roles (id, profile_id, entity_id, role_id, is_active)
VALUES
    ('e9000000-0000-4000-8000-000000000801',
     'e9000000-0000-4000-8000-000000000101',
     'e9000000-0000-4000-8000-000000000201',
     (SELECT id FROM core.user_roles WHERE name = 'Owner' AND is_active LIMIT 1),
     true),
    ('e9000000-0000-4000-8000-000000000802',
     'e9000000-0000-4000-8000-000000000102',
     'e9000000-0000-4000-8000-000000000202',
     (SELECT id FROM core.user_roles WHERE name = 'Owner' AND is_active LIMIT 1),
     true),
    ('e9000000-0000-4000-8000-000000000803',
     'e9000000-0000-4000-8000-000000000103',
     'e9000000-0000-4000-8000-000000000203',
     (SELECT id FROM core.user_roles WHERE name = 'Manager' AND is_active LIMIT 1),
     true);

INSERT INTO core.entity_members (
    entity_id, profile_id, role_id, can_manage, membership_status, is_active
)
VALUES
    ('e9000000-0000-4000-8000-000000000201',
     'e9000000-0000-4000-8000-000000000101',
     (SELECT id FROM core.user_roles WHERE name = 'Owner' AND is_active LIMIT 1),
     true, 'active', true),
    ('e9000000-0000-4000-8000-000000000202',
     'e9000000-0000-4000-8000-000000000102',
     (SELECT id FROM core.user_roles WHERE name = 'Owner' AND is_active LIMIT 1),
     true, 'active', true),
    ('e9000000-0000-4000-8000-000000000203',
     'e9000000-0000-4000-8000-000000000103',
     (SELECT id FROM core.user_roles WHERE name = 'Manager' AND is_active LIMIT 1),
     true, 'active', true);

INSERT INTO core.items (id, name)
VALUES ('e9000000-0000-4000-8000-000000000301', 'Seller Identity Item');

INSERT INTO core.item_variants (id, item_id, name)
VALUES ('e9000000-0000-4000-8000-000000000311',
        'e9000000-0000-4000-8000-000000000301', 'Seller Identity Variant');

INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status
) VALUES
    ('e9000000-0000-4000-8000-000000000501',
     'e9000000-0000-4000-8000-000000000201',
     'Entity Listing A', 10, 'KES', 'e9000000-0000-4000-8000-000000000011',
     'e9000000-0000-4000-8000-000000000311', 5,
     'e9000000-0000-4000-8000-000000000021', 'active'),
    ('e9000000-0000-4000-8000-000000000502',
     'e9000000-0000-4000-8000-000000000201',
     'Entity Listing B', 10, 'KES', 'e9000000-0000-4000-8000-000000000012',
     'e9000000-0000-4000-8000-000000000311', 5,
     'e9000000-0000-4000-8000-000000000021', 'active'),
    ('e9000000-0000-4000-8000-000000000503',
     'e9000000-0000-4000-8000-000000000202',
     'Individual Listing', 10, 'KES', 'e9000000-0000-4000-8000-000000000011',
     'e9000000-0000-4000-8000-000000000311', 5,
     'e9000000-0000-4000-8000-000000000021', 'active'),
    ('e9000000-0000-4000-8000-000000000504',
     'e9000000-0000-4000-8000-000000000202',
     'Draft Individual Listing', 10, 'KES', 'e9000000-0000-4000-8000-000000000011',
     'e9000000-0000-4000-8000-000000000311', 5,
     'e9000000-0000-4000-8000-000000000021', 'draft'),
    ('e9000000-0000-4000-8000-000000000505',
     'e9000000-0000-4000-8000-000000000203',
     'Trading Company Listing', 10, 'KES', 'e9000000-0000-4000-8000-000000000011',
     'e9000000-0000-4000-8000-000000000311', 5,
     'e9000000-0000-4000-8000-000000000021', 'active'),
    ('e9000000-0000-4000-8000-000000000506',
     'e9000000-0000-4000-8000-000000000204',
     'Cooperative Listing', 10, 'KES', 'e9000000-0000-4000-8000-000000000011',
     'e9000000-0000-4000-8000-000000000311', 5,
     'e9000000-0000-4000-8000-000000000021', 'active'),
    ('e9000000-0000-4000-8000-000000000507',
     'e9000000-0000-4000-8000-000000000201',
     'Draft Entity Listing', 10, 'KES', 'e9000000-0000-4000-8000-000000000011',
     'e9000000-0000-4000-8000-000000000311', 5,
     'e9000000-0000-4000-8000-000000000021', 'draft');

SET LOCAL ROLE anon;

DO $identity$
DECLARE
    v_entity_name text;
    v_first_name text;
    v_kind text;
    v_identity_count integer;
    v_listing_count integer;
    v_location_count integer;
    v_ids uuid[];
BEGIN
    SELECT seller_entity_name, seller_public_first_name, seller_kind
      INTO v_entity_name, v_first_name, v_kind
      FROM marketplace.get_public_listing_sellers(
          ARRAY['e9000000-0000-4000-8000-000000000501']::uuid[]
      );

    IF v_entity_name IS DISTINCT FROM 'JK Agrovet'
       OR v_first_name IS DISTINCT FROM 'James'
       OR v_kind IS DISTINCT FROM 'entity' THEN
        RAISE EXCEPTION 'entity seller identity is incorrect: %, %, %',
            v_entity_name, v_first_name, v_kind;
    END IF;

    SELECT seller_entity_name, seller_public_first_name, seller_kind
      INTO v_entity_name, v_first_name, v_kind
      FROM marketplace.get_public_listing_sellers(
          ARRAY['e9000000-0000-4000-8000-000000000503']::uuid[]
      );

    IF v_entity_name IS NOT NULL
       OR v_first_name IS DISTINCT FROM 'Alice'
       OR v_kind IS DISTINCT FROM 'individual' THEN
        RAISE EXCEPTION 'individual seller identity is incorrect: %, %, %',
            v_entity_name, v_first_name, v_kind;
    END IF;

    SELECT seller_entity_name, seller_public_first_name, seller_kind
      INTO v_entity_name, v_first_name, v_kind
      FROM marketplace.get_public_listing_sellers(
          ARRAY['e9000000-0000-4000-8000-000000000505']::uuid[]
      );

    IF v_entity_name IS DISTINCT FROM 'Acme Trading'
       OR v_first_name IS DISTINCT FROM 'Mary'
       OR v_kind IS DISTINCT FROM 'entity' THEN
        RAISE EXCEPTION 'authorized manager identity is incorrect: %, %, %',
            v_entity_name, v_first_name, v_kind;
    END IF;

    SELECT seller_entity_name, seller_public_first_name, seller_kind
      INTO v_entity_name, v_first_name, v_kind
      FROM marketplace.get_public_listing_sellers(
          ARRAY['e9000000-0000-4000-8000-000000000506']::uuid[]
      );

    IF v_entity_name IS DISTINCT FROM 'Coop Without Manager'
       OR v_first_name IS NOT NULL
       OR v_kind IS DISTINCT FROM 'entity' THEN
        RAISE EXCEPTION 'unresolved manager identity leaked a name: %, %, %',
            v_entity_name, v_first_name, v_kind;
    END IF;

    SELECT count(DISTINCT (seller_entity_id, seller_entity_name,
                           seller_public_first_name, seller_kind)),
           count(*)
      INTO v_identity_count, v_listing_count
      FROM marketplace.get_public_listing_sellers(ARRAY[
          'e9000000-0000-4000-8000-000000000501',
          'e9000000-0000-4000-8000-000000000502'
      ]::uuid[]);

    IF v_identity_count <> 1 OR v_listing_count <> 2 THEN
        RAISE EXCEPTION 'multiple entity locations changed the seller identity';
    END IF;

    SELECT count(DISTINCT location_id)
      INTO v_location_count
      FROM marketplace.listings
      WHERE id IN (
          'e9000000-0000-4000-8000-000000000501',
          'e9000000-0000-4000-8000-000000000502'
      );

    IF v_location_count <> 2 THEN
        RAISE EXCEPTION 'listing locations were collapsed';
    END IF;

    SELECT count(*)
      INTO v_listing_count
      FROM marketplace.get_public_listing_sellers(
          ARRAY['e9000000-0000-4000-8000-000000000504']::uuid[]
      );

    IF v_listing_count <> 0 THEN
        RAISE EXCEPTION 'non-public listing was enumerable';
    END IF;

    SELECT count(*)
      INTO v_listing_count
      FROM marketplace.get_public_listing_sellers(
          ARRAY['e9000000-0000-4000-8000-000000000999']::uuid[]
      );

    IF v_listing_count <> 0 THEN
        RAISE EXCEPTION 'unknown listing was enumerable';
    END IF;

    SELECT count(*)
      INTO v_listing_count
      FROM marketplace.get_public_listing_sellers(
          ARRAY[
              'e9000000-0000-4000-8000-000000000501',
              'e9000000-0000-4000-8000-000000000501'
          ]::uuid[]
      );

    IF v_listing_count <> 1 THEN
        RAISE EXCEPTION 'duplicate listing ids produced duplicate identities';
    END IF;

    SELECT count(*)
      INTO v_listing_count
      FROM marketplace.get_public_listing_sellers(NULL::uuid[]);

    IF v_listing_count <> 0 THEN
        RAISE EXCEPTION 'NULL listing ids returned rows';
    END IF;

    SELECT count(*)
      INTO v_listing_count
      FROM marketplace.get_public_listing_sellers(ARRAY[]::uuid[]);

    IF v_listing_count <> 0 THEN
        RAISE EXCEPTION 'empty listing ids returned rows';
    END IF;

    v_ids := array_fill(
        'e9000000-0000-4000-8000-000000000501'::uuid, ARRAY[201]
    );
    SELECT count(*)
      INTO v_listing_count
      FROM marketplace.get_public_listing_sellers(v_ids);

    IF v_listing_count <> 0 THEN
        RAISE EXCEPTION 'listing id cap was not enforced';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM marketplace.get_public_listing_sellers(ARRAY[
            'e9000000-0000-4000-8000-000000000501',
            'e9000000-0000-4000-8000-000000000503'
        ]::uuid[]) AS result
        WHERE result.seller_entity_name LIKE '%Kamau%'
           OR result.seller_public_first_name LIKE '%Kamau%'
           OR result.seller_entity_name LIKE '%Wanjiku%'
           OR result.seller_public_first_name LIKE '%Wanjiku%'
    ) THEN
        RAISE EXCEPTION 'full canonical profile name leaked';
    END IF;
END;
$identity$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config(
    'request.jwt.claim.sub',
    'e9000000-0000-4000-8000-000000000901',
    true
);

DO $authenticated_owner$
DECLARE
    v_listing_count integer;
BEGIN
    SELECT count(*)
      INTO v_listing_count
      FROM marketplace.get_public_listing_sellers(
          ARRAY['e9000000-0000-4000-8000-000000000507']::uuid[]
      );

    IF v_listing_count <> 1 THEN
        RAISE EXCEPTION 'entity owner cannot read own non-public identity';
    END IF;
END;
$authenticated_owner$;

SELECT set_config(
    'request.jwt.claim.sub',
    'e9000000-0000-4000-8000-000000000902',
    true
);

DO $authenticated_non_owner$
DECLARE
    v_listing_count integer;
BEGIN
    SELECT count(*)
      INTO v_listing_count
      FROM marketplace.get_public_listing_sellers(
          ARRAY['e9000000-0000-4000-8000-000000000507']::uuid[]
      );

    IF v_listing_count <> 0 THEN
        RAISE EXCEPTION 'non-owner authenticated caller can enumerate identity';
    END IF;
END;
$authenticated_non_owner$;

ROLLBACK;
