-- ============================================================================
-- 20261115000001_marketplace_contact_unlock_prerequisites
-- ----------------------------------------------------------------------------
-- Repository-only prerequisite migration.
--
-- Scope:
--   * marketplace.listings: standalone quantity support and source constraints.
--   * marketplace.contact_unlocks: Finance obligation linkage and uniqueness.
--   * restricted ACL/RLS posture for contact_unlocks.
--
-- This migration intentionally does NOT include:
--   * buyer_pricing ACL correction
--   * marketplace.unlock_contact()
--   * marketplace.assert_contact_unlock_listing_eligible()
--   * payment/M-Pesa changes
--   * Finance integration functions
--   * any environment data
--
-- Requires the base marketplace tables and finance.obligations to exist.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Preconditions
-- ----------------------------------------------------------------------------
DO $preconditions$
BEGIN
    IF to_regclass('marketplace.listings') IS NULL
       OR to_regclass('marketplace.contact_unlocks') IS NULL
       OR to_regclass('finance.obligations') IS NULL THEN
        RAISE EXCEPTION
            'Missing prerequisite tables: marketplace.listings, marketplace.contact_unlocks, finance.obligations';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM marketplace.contact_unlocks
         GROUP BY listing_id, entity_id
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION
            'Cannot add contact_unlocks_listing_entity_key: duplicate (listing_id, entity_id) rows exist';
    END IF;

END;
$preconditions$;

-- ----------------------------------------------------------------------------
-- marketplace.listings: standalone quantity support
-- ----------------------------------------------------------------------------
ALTER TABLE marketplace.listings
    ADD COLUMN IF NOT EXISTS quantity_offered numeric;

ALTER TABLE marketplace.listings
    ALTER COLUMN stock_id DROP NOT NULL;

DO $listings_constraints$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'marketplace.listings'::regclass
           AND conname = 'listings_quantity_offered_positive'
    ) THEN
        ALTER TABLE marketplace.listings
            ADD CONSTRAINT listings_quantity_offered_positive
            CHECK (quantity_offered IS NULL OR quantity_offered > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'marketplace.listings'::regclass
           AND conname = 'listings_quantity_offered_unit_required'
    ) THEN
        ALTER TABLE marketplace.listings
            ADD CONSTRAINT listings_quantity_offered_unit_required
            CHECK (quantity_offered IS NULL OR unit_id IS NOT NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'marketplace.listings'::regclass
           AND conname = 'listings_quantity_source_consistency'
    ) THEN
        ALTER TABLE marketplace.listings
            ADD CONSTRAINT listings_quantity_source_consistency
            CHECK (
                (stock_id IS NOT NULL AND quantity_offered IS NULL)
                OR
                (stock_id IS NULL AND quantity_offered IS NOT NULL)
            );
    END IF;
END;
$listings_constraints$;

-- ----------------------------------------------------------------------------
-- marketplace.contact_unlocks: Finance obligation linkage and uniqueness
-- ----------------------------------------------------------------------------
ALTER TABLE marketplace.contact_unlocks
    ADD COLUMN IF NOT EXISTS finance_obligation_id uuid;

DO $contact_unlock_data_checks$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM marketplace.contact_unlocks
         WHERE finance_obligation_id IS NOT NULL
         GROUP BY finance_obligation_id
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION
            'Cannot add contact_unlocks_finance_obligation_id_key: duplicate finance_obligation_id rows exist';
    END IF;
END;
$contact_unlock_data_checks$;

DO $contact_unlock_constraints$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'marketplace.contact_unlocks'::regclass
           AND conname = 'contact_unlocks_finance_obligation_id_fkey'
    ) THEN
        ALTER TABLE marketplace.contact_unlocks
            ADD CONSTRAINT contact_unlocks_finance_obligation_id_fkey
            FOREIGN KEY (finance_obligation_id)
            REFERENCES finance.obligations(id)
            ON DELETE RESTRICT;
    END IF;
END;
$contact_unlock_constraints$;

CREATE UNIQUE INDEX IF NOT EXISTS contact_unlocks_finance_obligation_id_key
    ON marketplace.contact_unlocks (finance_obligation_id)
    WHERE finance_obligation_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS contact_unlocks_listing_entity_key
    ON marketplace.contact_unlocks (listing_id, entity_id);

-- ----------------------------------------------------------------------------
-- Restricted ACL/RLS posture
-- ----------------------------------------------------------------------------
ALTER TABLE marketplace.contact_unlocks ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE marketplace.contact_unlocks
    FROM PUBLIC, "anon", "authenticated", "service_role";

COMMIT;
