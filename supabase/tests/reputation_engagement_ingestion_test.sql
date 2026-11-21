-- ============================================================================
-- reputation_engagement_ingestion_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE test for Phase 2C-1 ingestion.
--
-- Run only against a local/disposable database with all migrations applied.
-- Never run against production.
-- ============================================================================
BEGIN;

-- The production schema has NOT NULL on these columns. The test temporarily
-- relaxes them to exercise the gateway's missing-identity rejection paths.
ALTER TABLE commerce.orders ALTER COLUMN buyer_id DROP NOT NULL;
ALTER TABLE commerce.orders ALTER COLUMN supplier_id DROP NOT NULL;
ALTER TABLE commerce.orders ALTER COLUMN listing_id DROP NOT NULL;

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('80000000-0000-4000-8000-000000000001', 'Ingestion Test Country', 'IG', 'IGT', '9995', true);
INSERT INTO core.locations (id, name, country_id, is_active)
VALUES ('80000000-0000-4000-8000-000000000002', 'Ingestion Test Location',
        '80000000-0000-4000-8000-000000000001', true);
INSERT INTO core.units (id, name, symbol, unit_type)
VALUES ('80000000-0000-4000-8000-000000000003', 'ingestion-test-kilogram', 'kg', 'mass');

SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', 'service_role', true),
    set_config('request.jwt.claims', '{"role":"service_role"}', true);
INSERT INTO users.profiles (id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES
    ('81000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000901',
     'Ingestion Buyer', '80000000-0000-4000-8000-000000000001', true, 'active'),
    ('81000000-0000-4000-8000-000000000002', '81000000-0000-4000-8000-000000000902',
     'Ingestion Seller', '80000000-0000-4000-8000-000000000001', true, 'active');
SELECT
    set_config('request.jwt.claim.sub', '', true),
    set_config('request.jwt.claim.role', '', true),
    set_config('request.jwt.claims', '', true);

INSERT INTO core.entities (id, name, entity_type, owner_id, is_active, verification_status)
VALUES
    ('82000000-0000-4000-8000-000000000001', 'Ingestion Buyer Entity',
     'individual_pro', '81000000-0000-4000-8000-000000000001', true, 'verified'),
    ('82000000-0000-4000-8000-000000000002', 'Ingestion Seller Entity',
     'farm', '81000000-0000-4000-8000-000000000002', true, 'verified'),
    ('82000000-0000-4000-8000-000000000012', 'Ingestion Retired Seller Entity',
     'farm', '81000000-0000-4000-8000-000000000002', true, 'verified');

INSERT INTO core.items (id, name)
VALUES ('83000000-0000-4000-8000-000000000001', 'Ingestion Test Item');
INSERT INTO core.item_variants (id, item_id, name)
VALUES ('83000000-0000-4000-8000-000000000002',
        '83000000-0000-4000-8000-000000000001', 'Ingestion Test Variant');

INSERT INTO commerce.stock_registry (
    id, entity_id, business_profile_id, variant_id, product_id, location_id,
    quantity, reserved_quantity, unit_id, status
) VALUES (
    '83000000-0000-4000-8000-000000000004',
    '82000000-0000-4000-8000-000000000002',
    '84000000-0000-4000-8000-000000000001',
    '83000000-0000-4000-8000-000000000002',
    '83000000-0000-4000-8000-000000000001',
    '80000000-0000-4000-8000-000000000002',
    1000.00, 0.00, '80000000-0000-4000-8000-000000000003', 'active'
);

INSERT INTO marketplace.listings (
    id, entity_id, title, price_per_unit, currency, location_id,
    variant_id, quantity_offered, unit_id, status, stock_id
) VALUES (
    '83000000-0000-4000-8000-000000000003',
    '82000000-0000-4000-8000-000000000002',
    'Ingestion Test Listing', 50.00, 'KES',
    '80000000-0000-4000-8000-000000000002',
    '83000000-0000-4000-8000-000000000002',
    1000.00, '80000000-0000-4000-8000-000000000003', 'active',
    '83000000-0000-4000-8000-000000000004'
);

INSERT INTO commerce.business_profiles (
    id, entity_type, primary_contact_id, supplier_name, verification_status,
    user_active, entity_id, is_active
) VALUES (
    '84000000-0000-4000-8000-000000000001', 'farm',
    '81000000-0000-4000-8000-000000000002', 'Ingestion Test Supplier',
    'verified', true, '82000000-0000-4000-8000-000000000002', true
);

INSERT INTO commerce.orders (
    id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
    payment_status, order_date, delivered_at, delivery_date, entity_id,
    order_kind, buyer_entity_id, seller_entity_id, currency, unit_id,
    status_changed_by_profile_id
) VALUES
    ('85000000-0000-4000-8000-000000000001',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 2.00, 100.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:00:00Z', '2026-11-20T10:00:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000002',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 2.00, 100.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:05:00Z', '2026-11-20T10:05:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000003',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'shipped', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:10:00Z', '2026-11-20T10:10:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000004',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:15:00Z', '2026-11-20T10:15:00Z',
     '82000000-0000-4000-8000-000000000002', 'service',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000005',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', NULL, NULL,
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000006',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:20:00Z', '2026-11-20T10:20:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     NULL, '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000007',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:25:00Z', '2026-11-20T10:25:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', NULL,
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000008',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     NULL, 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:30:00Z', '2026-11-20T10:30:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000009',
     '81000000-0000-4000-8000-000000000001', NULL,
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:35:00Z', '2026-11-20T10:35:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000010',
     NULL, '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:40:00Z', '2026-11-20T10:40:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000011',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:45:00Z', '2026-11-20T10:45:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000012',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:50:00Z', '2026-11-20T10:50:00Z',
     '82000000-0000-4000-8000-000000000012', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000012',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000013',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T10:55:00Z', '2026-11-20T10:55:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000014',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T11:00:00Z', '2026-11-20T11:00:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000015',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T11:05:00Z', '2026-11-20T11:05:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001'),
    ('85000000-0000-4000-8000-000000000016',
     '81000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000003',
     '84000000-0000-4000-8000-000000000001', 1.00, 50.00, 'delivered', 'pending',
     '2026-11-20T09:00:00Z', '2026-11-20T11:10:00Z', '2026-11-20T11:10:00Z',
     '82000000-0000-4000-8000-000000000002', 'stock',
     '82000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002',
     'KES', '80000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001');

INSERT INTO commerce.order_items (
    id, order_id, listing_id, product_id, quantity, unit, price_per_unit,
    stock_id, variant_id, unit_id
) VALUES
    ('86000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-000000000001',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000002', '85000000-0000-4000-8000-000000000001',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000020', '85000000-0000-4000-8000-000000000002',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     2.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000003', '85000000-0000-4000-8000-000000000003',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000004', '85000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000005', '85000000-0000-4000-8000-000000000005',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000006', '85000000-0000-4000-8000-000000000006',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000007', '85000000-0000-4000-8000-000000000007',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000008', '85000000-0000-4000-8000-000000000008',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000009', '85000000-0000-4000-8000-000000000009',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000010', '85000000-0000-4000-8000-000000000010',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000012', '85000000-0000-4000-8000-000000000012',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000013', '85000000-0000-4000-8000-000000000013',
     '83000000-0000-4000-8000-000000000003', '89999999-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000014', '85000000-0000-4000-8000-000000000014',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000015', '85000000-0000-4000-8000-000000000015',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003'),
    ('86000000-0000-4000-8000-000000000016', '85000000-0000-4000-8000-000000000016',
     '83000000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000001',
     1.00, 'kg', 50.00, '83000000-0000-4000-8000-000000000004',
     '83000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003');

CREATE FUNCTION pg_temp.snapshot_hash(p_snapshot jsonb)
RETURNS bytea
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT pg_catalog.sha256(convert_to(p_snapshot::text, 'UTF8'))
$$;

CREATE FUNCTION pg_temp.event_hash(
    p_event_at timestamptz,
    p_reference text
)
RETURNS bytea
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT pg_catalog.sha256(
        convert_to(
            jsonb_build_object(
                'event_version', 1,
                'event_type', 'order_delivered',
                'event_at', to_char(
                    p_event_at AT TIME ZONE 'UTC',
                    'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
                ),
                'source_namespace', 'vunio',
                'source_event_reference', p_reference,
                'actor_profile_id', NULL::text,
                'details', '{}'::jsonb
            )::text,
            'UTF8'
        )
    )
$$;

CREATE FUNCTION pg_temp.expected_engagement_snapshot(p_order_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT jsonb_build_object(
        'snapshot_schema_version', 1,
        'engagement_kind', 'vunio_order',
        'source', jsonb_build_object(
            'source_system', 'vunio',
            'source_reference', o.id::text
        ),
        'order', jsonb_build_object(
            'id', o.id,
            'order_kind', o.order_kind,
            'order_date', to_char(
                o.order_date AT TIME ZONE 'UTC',
                'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
            ),
            'buyer_id', o.buyer_id,
            'buyer_entity_id', o.buyer_entity_id,
            'seller_entity_id', o.seller_entity_id,
            'supplier_id', o.supplier_id,
            'listing_id', o.listing_id,
            'currency', o.currency,
            'quantity', o.quantity::text,
            'total_amount', o.total_amount::text,
            'unit_id', o.unit_id
        ),
        'items', COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', oi.id,
                        'listing_id', oi.listing_id,
                        'product_id', oi.product_id,
                        'variant_id', oi.variant_id,
                        'stock_id', oi.stock_id,
                        'quantity', oi.quantity::text,
                        'unit', oi.unit,
                        'unit_id', oi.unit_id,
                        'price_per_unit', oi.price_per_unit::text
                    )
                    ORDER BY oi.id
                )
                FROM commerce.order_items AS oi
                WHERE oi.order_id = o.id
            ),
            '[]'::jsonb
        )
    )
    FROM commerce.orders AS o
    WHERE o.id = p_order_id
$$;

CREATE FUNCTION pg_temp.assert_ingest(
    p_order_id uuid,
    p_expected_outcome text,
    p_expected_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_result record;
BEGIN
    SELECT * INTO v_result
      FROM system.ingest_reputation_stock_order_engagement(p_order_id);

    IF v_result.outcome IS DISTINCT FROM p_expected_outcome
       OR (
           p_expected_reason IS NOT NULL
           AND v_result.reason_code IS DISTINCT FROM p_expected_reason
       ) THEN
        RAISE EXCEPTION 'ingest outcome mismatch for %: expected %/%, got %/%',
            p_order_id, p_expected_outcome, p_expected_reason,
            v_result.outcome, v_result.reason_code;
    END IF;
END;
$$;

-- Retire the canonical seller entity subject used by the retired-subject case.
DO $retire$
DECLARE
    v_subject_id uuid;
BEGIN
    v_subject_id := reputation.register_subject(
        'entity', 'seller', '82000000-0000-4000-8000-000000000012'
    );
    PERFORM reputation.retire_subject(v_subject_id);
END;
$retire$;

-- Incomplete existing engagement for repair. Snapshot matches authoritative,
-- but seller participant, most subjects, and order_delivered are missing.
INSERT INTO reputation.engagements (
    id, engagement_kind, source_system, source_reference, commerce_order_id,
    source_snapshot, source_snapshot_hash, source_occurred_at, currency, gross_amount
)
SELECT
    '87000000-0000-4000-8000-000000000002',
    'vunio_order', 'vunio', o.id::text, o.id,
    pg_temp.expected_engagement_snapshot(o.id),
    pg_temp.snapshot_hash(pg_temp.expected_engagement_snapshot(o.id)),
    o.delivered_at, o.currency, o.total_amount
FROM commerce.orders AS o
WHERE o.id = '85000000-0000-4000-8000-000000000002';

INSERT INTO reputation.engagement_participants (
    engagement_id, party_role, profile_id, entity_id
) VALUES (
    '87000000-0000-4000-8000-000000000002', 'buyer',
    '81000000-0000-4000-8000-000000000001',
    '82000000-0000-4000-8000-000000000001'
);

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key, details
) VALUES (
    '87000000-0000-4000-8000-000000000002', 'reputation',
    'engagement_recorded', clock_timestamp(), 'engagement-recorded',
    '{"source_integrity_status":"consistent"}'
);

DO $repair_seed$
DECLARE
    v_subject_id uuid;
BEGIN
    v_subject_id := reputation.register_subject(
        'entity', 'seller', '82000000-0000-4000-8000-000000000002'
    );
    INSERT INTO reputation.engagement_subjects (
        engagement_id, subject_id, relationship, source_fact
    ) VALUES (
        '87000000-0000-4000-8000-000000000002',
        v_subject_id,
        'seller_entity',
        jsonb_build_object(
            'seller_entity_id', '82000000-0000-4000-8000-000000000002'
        )
    );
END;
$repair_seed$;

-- Voided engagement fixture.
INSERT INTO reputation.engagements (
    id, engagement_kind, source_system, source_reference, commerce_order_id,
    source_snapshot, source_snapshot_hash, source_occurred_at, currency, gross_amount
)
SELECT
    '87000000-0000-4000-8000-000000000014',
    'vunio_order', 'vunio', o.id::text, o.id,
    '{"snapshot_version":999}'::jsonb,
    pg_temp.snapshot_hash('{"snapshot_version":999}'::jsonb),
    o.delivered_at, o.currency, o.total_amount
FROM commerce.orders AS o
WHERE o.id = '85000000-0000-4000-8000-000000000014';

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key, details
) VALUES
    ('87000000-0000-4000-8000-000000000014', 'reputation',
     'engagement_recorded', '2026-11-20T11:00:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}');

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key,
    source_namespace, source_event_reference, payload_hash, details
)
SELECT
    '87000000-0000-4000-8000-000000000014', 'source', 'order_delivered',
    o.delivered_at, 'vunio:delivered', 'vunio',
    'order:' || o.id::text || ':delivered',
    pg_temp.event_hash(o.delivered_at, 'order:' || o.id::text || ':delivered'),
    '{}'
FROM commerce.orders AS o
WHERE o.id = '85000000-0000-4000-8000-000000000014';

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key, details
) VALUES (
    '87000000-0000-4000-8000-000000000014', 'reputation',
    'engagement_voided', '2026-11-20T11:00:02Z', 'void-1',
    '{"invalidity_code":"test_void"}'
);

-- Snapshot-conflict engagement fixture.
INSERT INTO reputation.engagements (
    id, engagement_kind, source_system, source_reference, commerce_order_id,
    source_snapshot, source_snapshot_hash, source_occurred_at, currency, gross_amount
)
SELECT
    '87000000-0000-4000-8000-000000000015',
    'vunio_order', 'vunio', o.id::text, o.id,
    '{"snapshot_version":999}'::jsonb,
    pg_temp.snapshot_hash('{"snapshot_version":999}'::jsonb),
    o.delivered_at, o.currency, o.total_amount
FROM commerce.orders AS o
WHERE o.id = '85000000-0000-4000-8000-000000000015';

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key, details
) VALUES
    ('87000000-0000-4000-8000-000000000015', 'reputation',
     'engagement_recorded', '2026-11-20T11:05:01Z', 'engagement-recorded',
     '{"source_integrity_status":"consistent"}');

INSERT INTO reputation.engagement_events (
    engagement_id, event_origin, event_type, event_at, event_key,
    source_namespace, source_event_reference, payload_hash, details
)
SELECT
    '87000000-0000-4000-8000-000000000015', 'source', 'order_delivered',
    o.delivered_at, 'vunio:delivered', 'vunio',
    'order:' || o.id::text || ':delivered',
    pg_temp.event_hash(o.delivered_at, 'order:' || o.id::text || ':delivered'),
    '{}'
FROM commerce.orders AS o
WHERE o.id = '85000000-0000-4000-8000-000000000015';

-- ----------------------------------------------------------------------------
-- Schema and security
-- ----------------------------------------------------------------------------
DO $schema$
DECLARE
    v_rls boolean;
BEGIN
    IF to_regprocedure('reputation.ingest_stock_order_engagement(uuid)') IS NULL
       OR to_regprocedure('system.ingest_reputation_stock_order_engagement(uuid)') IS NULL THEN
        RAISE EXCEPTION 'Phase 2C-1 ingestion functions are missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname='reputation'
           AND p.proname='ingest_stock_order_engagement'
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.prosecdef = true
           AND p.proconfig @> ARRAY['search_path=pg_catalog, reputation, commerce, core, users']
    ) THEN
        RAISE EXCEPTION 'private ingestion function security properties are wrong';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname='system'
           AND p.proname='ingest_reputation_stock_order_engagement'
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.prosecdef = true
           AND p.proconfig @> ARRAY['search_path=pg_catalog, system, reputation']
    ) THEN
        RAISE EXCEPTION 'system ingestion gateway security properties are wrong';
    END IF;

    IF has_function_privilege('service_role',
           'reputation.ingest_stock_order_engagement(uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated',
           'reputation.ingest_stock_order_engagement(uuid)', 'EXECUTE')
       OR has_function_privilege('anon',
           'reputation.ingest_stock_order_engagement(uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'private ingestion function is directly executable';
    END IF;

    IF NOT has_function_privilege('service_role',
           'system.ingest_reputation_stock_order_engagement(uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated',
           'system.ingest_reputation_stock_order_engagement(uuid)', 'EXECUTE')
       OR has_function_privilege('anon',
           'system.ingest_reputation_stock_order_engagement(uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'system ingestion gateway grants are wrong';
    END IF;

    SELECT relrowsecurity INTO v_rls
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='reputation' AND c.relname='engagements';
    IF v_rls IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'engagements RLS is not enabled';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_policies
         WHERE schemaname='reputation'
           AND tablename IN (
               'engagements','engagement_participants',
               'engagement_subjects','engagement_events'
           )
    ) THEN
        RAISE EXCEPTION 'unexpected Reputation policies exist';
    END IF;

    IF has_table_privilege('anon','reputation.engagements','SELECT')
       OR has_table_privilege('authenticated','reputation.engagements','SELECT')
       OR has_table_privilege('service_role','reputation.engagements','SELECT')
       OR has_table_privilege('anon','reputation.engagement_events','SELECT')
       OR has_table_privilege('authenticated','reputation.engagement_events','SELECT')
       OR has_table_privilege('service_role','reputation.engagement_events','SELECT') THEN
        RAISE EXCEPTION 'unexpected Reputation table access';
    END IF;
END;
$schema$;

-- ----------------------------------------------------------------------------
-- Successful creation and multi-item snapshot
-- ----------------------------------------------------------------------------
DO $create$
DECLARE
    v_result record;
    v_engagement reputation.engagements%ROWTYPE;
    v_expected_hash bytea;
    v_actual_hash bytea;
    v_source_event reputation.engagement_events%ROWTYPE;
    v_expected_event_hash bytea;
BEGIN
    SELECT * INTO v_result
      FROM system.ingest_reputation_stock_order_engagement(
          '85000000-0000-4000-8000-000000000001'
      );

    IF v_result.outcome <> 'created'
       OR v_result.participant_count <> 2
       OR v_result.subject_count <> 4
       OR v_result.source_event_id IS NULL
       OR v_result.engagement_id IS NULL THEN
        RAISE EXCEPTION 'multi-item creation outcome mismatch: %/%/%/%',
            v_result.outcome, v_result.participant_count,
            v_result.subject_count, v_result.source_event_id;
    END IF;

    SELECT * INTO v_engagement
      FROM reputation.engagements
     WHERE id = v_result.engagement_id;

    IF v_engagement.engagement_kind <> 'vunio_order'
       OR v_engagement.source_system <> 'vunio'
       OR v_engagement.source_reference <> '85000000-0000-4000-8000-000000000001'
       OR v_engagement.commerce_order_id <> '85000000-0000-4000-8000-000000000001'
       OR v_engagement.currency <> 'KES'
       OR v_engagement.gross_amount <> 100.00 THEN
        RAISE EXCEPTION 'engagement identity mismatch';
    END IF;

    v_expected_hash := pg_catalog.sha256(
        convert_to(v_engagement.source_snapshot::text, 'UTF8')
    );
    IF v_engagement.source_snapshot_hash IS DISTINCT FROM v_expected_hash THEN
        RAISE EXCEPTION 'engagement snapshot hash mismatch';
    END IF;

    IF v_engagement.source_snapshot #>> '{source,source_system}' <> 'vunio'
       OR v_engagement.source_snapshot #>> '{source,source_reference}'
          <> '85000000-0000-4000-8000-000000000001'
       OR v_engagement.source_snapshot #>> '{order,id}'
          <> '85000000-0000-4000-8000-000000000001'
       OR jsonb_array_length(v_engagement.source_snapshot->'items') <> 2
       OR v_engagement.source_snapshot::text LIKE '%payment_status%'
       OR v_engagement.source_snapshot::text LIKE '%status_reason%'
       OR v_engagement.source_snapshot::text LIKE '%updated_at%' THEN
        RAISE EXCEPTION 'engagement snapshot content mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.engagement_subjects es
         WHERE es.engagement_id = v_result.engagement_id
    ) OR (SELECT count(*) FROM reputation.engagement_subjects
           WHERE engagement_id = v_result.engagement_id) <> 4 THEN
        RAISE EXCEPTION 'subject association count mismatch';
    END IF;

    SELECT * INTO v_source_event
      FROM reputation.engagement_events
     WHERE id = v_result.source_event_id;

    v_expected_event_hash := pg_temp.event_hash(
        v_source_event.event_at,
        'order:85000000-0000-4000-8000-000000000001:delivered'
    );

    IF v_source_event.event_type <> 'order_delivered'
       OR v_source_event.source_namespace <> 'vunio'
       OR v_source_event.source_event_reference
          <> 'order:85000000-0000-4000-8000-000000000001:delivered'
       OR v_source_event.event_key <> 'vunio:delivered'
       OR v_source_event.event_at <> '2026-11-20T10:00:00Z'
       OR v_source_event.payload_hash IS DISTINCT FROM v_expected_event_hash THEN
        RAISE EXCEPTION 'order_delivered event mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.engagement_events
         WHERE engagement_id = v_result.engagement_id
           AND event_type = 'engagement_recorded'
    ) THEN
        RAISE EXCEPTION 'engagement_recorded event missing';
    END IF;
END;
$create$;

-- ----------------------------------------------------------------------------
-- Idempotency
-- ----------------------------------------------------------------------------
DO $idempotency$
DECLARE
    v_result record;
    v_first uuid;
BEGIN
    SELECT id INTO v_first
      FROM reputation.engagements
     WHERE commerce_order_id = '85000000-0000-4000-8000-000000000001';

    SELECT * INTO v_result
      FROM system.ingest_reputation_stock_order_engagement(
          '85000000-0000-4000-8000-000000000001'
      );

    IF v_result.outcome <> 'already_ingested'
       OR v_result.engagement_id <> v_first THEN
        RAISE EXCEPTION 'idempotent retry mismatch: %/%', v_result.outcome, v_result.engagement_id;
    END IF;

    IF (SELECT count(*) FROM reputation.engagements
         WHERE commerce_order_id = '85000000-0000-4000-8000-000000000001') <> 1
       OR (SELECT count(*) FROM reputation.engagement_participants
            WHERE engagement_id = v_first) <> 2
       OR (SELECT count(*) FROM reputation.engagement_subjects
            WHERE engagement_id = v_first) <> 4
       OR (SELECT count(*) FROM reputation.engagement_events
            WHERE engagement_id = v_first) <> 2 THEN
        RAISE EXCEPTION 'idempotent retry created duplicates';
    END IF;
END;
$idempotency$;

-- ----------------------------------------------------------------------------
-- Repair
-- ----------------------------------------------------------------------------
DO $repair$
DECLARE
    v_result record;
    v_buyer reputation.engagement_participants%ROWTYPE;
    v_buyer_before reputation.engagement_participants%ROWTYPE;
    v_snapshot_before jsonb;
    v_snapshot_after jsonb;
BEGIN
    SELECT * INTO v_buyer_before
      FROM reputation.engagement_participants
     WHERE engagement_id = '87000000-0000-4000-8000-000000000002'
       AND party_role = 'buyer';
    SELECT source_snapshot INTO v_snapshot_before
      FROM reputation.engagements
     WHERE id = '87000000-0000-4000-8000-000000000002';

    SELECT * INTO v_result
      FROM system.ingest_reputation_stock_order_engagement(
          '85000000-0000-4000-8000-000000000002'
      );

    IF v_result.outcome <> 'repaired'
       OR v_result.engagement_id <> '87000000-0000-4000-8000-000000000002'
       OR v_result.participant_count <> 2
       OR v_result.subject_count <> 4 THEN
        RAISE EXCEPTION 'repair outcome mismatch: %/%/%/%',
            v_result.outcome, v_result.engagement_id,
            v_result.participant_count, v_result.subject_count;
    END IF;

    SELECT * INTO v_buyer
      FROM reputation.engagement_participants
     WHERE engagement_id = '87000000-0000-4000-8000-000000000002'
       AND party_role = 'buyer';
    IF v_buyer.profile_id IS DISTINCT FROM v_buyer_before.profile_id
       OR v_buyer.entity_id IS DISTINCT FROM v_buyer_before.entity_id THEN
        RAISE EXCEPTION 'repair rewrote existing buyer participant';
    END IF;

    SELECT source_snapshot INTO v_snapshot_after
      FROM reputation.engagements
     WHERE id = '87000000-0000-4000-8000-000000000002';
    IF v_snapshot_after IS DISTINCT FROM v_snapshot_before THEN
        RAISE EXCEPTION 'repair rewrote engagement snapshot';
    END IF;

    IF (SELECT count(*) FROM reputation.engagement_events
         WHERE engagement_id = '87000000-0000-4000-8000-000000000002'
           AND event_type = 'engagement_recorded') <> 1
       OR (SELECT count(*) FROM reputation.engagement_events
            WHERE engagement_id = '87000000-0000-4000-8000-000000000002'
              AND event_type = 'order_delivered') <> 1 THEN
        RAISE EXCEPTION 'repair event counts are wrong';
    END IF;

    SELECT * INTO v_result
      FROM system.ingest_reputation_stock_order_engagement(
          '85000000-0000-4000-8000-000000000002'
      );
    IF v_result.outcome <> 'already_ingested' THEN
        RAISE EXCEPTION 'post-repair retry was not idempotent';
    END IF;
END;
$repair$;

-- ----------------------------------------------------------------------------
-- Ineligible source data
-- ----------------------------------------------------------------------------
DO $ineligible$
BEGIN
    BEGIN
        PERFORM system.ingest_reputation_stock_order_engagement(gen_random_uuid());
        RAISE EXCEPTION 'missing order unexpectedly succeeded';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;

    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000003', 'ineligible', 'not_delivered');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000004', 'ineligible', 'not_stock_order');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000005', 'ineligible', 'missing_delivered_at');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000006', 'ineligible', 'missing_buyer_entity');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000007', 'ineligible', 'missing_seller_entity');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000008', 'ineligible', 'missing_supplier');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000009', 'ineligible', 'missing_listing');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000010', 'ineligible', 'missing_buyer_profile');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000011', 'ineligible', 'missing_order_items');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000012', 'ineligible', 'subject_retired');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000013', 'ineligible', 'subject_missing');
    PERFORM pg_temp.assert_ingest('85000000-0000-4000-8000-000000000014', 'ineligible', 'engagement_voided');

    IF EXISTS (
        SELECT 1 FROM reputation.engagements
         WHERE commerce_order_id IN (
             '85000000-0000-4000-8000-000000000003',
             '85000000-0000-4000-8000-000000000004',
             '85000000-0000-4000-8000-000000000005',
             '85000000-0000-4000-8000-000000000006',
             '85000000-0000-4000-8000-000000000007',
             '85000000-0000-4000-8000-000000000008',
             '85000000-0000-4000-8000-000000000009',
             '85000000-0000-4000-8000-000000000010',
             '85000000-0000-4000-8000-000000000011',
             '85000000-0000-4000-8000-000000000012',
             '85000000-0000-4000-8000-000000000013'
         )
    ) THEN
        RAISE EXCEPTION 'ineligible ingestion created engagements';
    END IF;
END;
$ineligible$;

-- ----------------------------------------------------------------------------
-- Snapshot conflict and actual source-event conflict
-- ----------------------------------------------------------------------------
DO $conflicts$
DECLARE
    v_result record;
    v_snapshot_before jsonb;
    v_snapshot_after jsonb;
    v_count integer;
BEGIN
    PERFORM pg_temp.assert_ingest(
        '85000000-0000-4000-8000-000000000015',
        'source_conflict',
        'engagement_snapshot_conflict'
    );

    SELECT source_snapshot INTO v_snapshot_before
      FROM reputation.engagements
     WHERE id = '87000000-0000-4000-8000-000000000015';
    PERFORM pg_temp.assert_ingest(
        '85000000-0000-4000-8000-000000000015',
        'source_conflict',
        'engagement_snapshot_conflict'
    );
    SELECT source_snapshot INTO v_snapshot_after
      FROM reputation.engagements
     WHERE id = '87000000-0000-4000-8000-000000000015';
    IF v_snapshot_after IS DISTINCT FROM v_snapshot_before THEN
        RAISE EXCEPTION 'snapshot conflict rewrote existing engagement';
    END IF;

    SELECT * INTO v_result
      FROM system.ingest_reputation_stock_order_engagement(
          '85000000-0000-4000-8000-000000000016'
      );
    IF v_result.outcome <> 'created' THEN
        RAISE EXCEPTION 'source conflict fixture creation failed';
    END IF;

    UPDATE commerce.orders
       SET delivered_at = '2026-11-20T11:59:00Z',
           delivery_date = '2026-11-20T11:59:00Z',
           updated_at = now()
     WHERE id = '85000000-0000-4000-8000-000000000016';

    PERFORM pg_temp.assert_ingest(
        '85000000-0000-4000-8000-000000000016',
        'source_conflict',
        'source_event_conflict'
    );

    SELECT count(*) INTO v_count
      FROM reputation.engagement_events
     WHERE engagement_id = v_result.engagement_id
       AND event_type = 'source_event_conflict';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'source event conflict audit count is %', v_count;
    END IF;

    PERFORM pg_temp.assert_ingest(
        '85000000-0000-4000-8000-000000000016',
        'source_conflict',
        'source_event_conflict'
    );

    SELECT count(*) INTO v_count
      FROM reputation.engagement_events
     WHERE engagement_id = v_result.engagement_id
       AND event_type = 'source_event_conflict';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'source event conflict audit was duplicated';
    END IF;
END;
$conflicts$;

-- ----------------------------------------------------------------------------
-- Service-role gateway and direct-access denial
-- ----------------------------------------------------------------------------
SET LOCAL ROLE service_role;

DO $service_role$
DECLARE
    v_result record;
BEGIN
    SELECT * INTO v_result
      FROM system.ingest_reputation_stock_order_engagement(
          '85000000-0000-4000-8000-000000000001'
      );
    IF v_result.outcome <> 'already_ingested' THEN
        RAISE EXCEPTION 'service_role gateway call failed';
    END IF;

    BEGIN
        PERFORM 1 FROM reputation.engagements LIMIT 1;
        RAISE EXCEPTION 'service_role read engagements';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        PERFORM reputation.ingest_stock_order_engagement(
            '85000000-0000-4000-8000-000000000001'
        );
        RAISE EXCEPTION 'service_role executed private ingestion';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$service_role$;

RESET ROLE;

SET LOCAL ROLE authenticated;

DO $authenticated$
BEGIN
    BEGIN
        PERFORM system.ingest_reputation_stock_order_engagement(
            '85000000-0000-4000-8000-000000000001'
        );
        RAISE EXCEPTION 'authenticated executed gateway';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$authenticated$;

RESET ROLE;

SET CONSTRAINTS
    reputation.reputation_engagements_initial_events_complete,
    reputation.reputation_engagement_events_complete
    IMMEDIATE;

ROLLBACK;
