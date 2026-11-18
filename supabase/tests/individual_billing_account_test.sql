-- ============================================================================
-- individual_billing_account_test.sql
-- ----------------------------------------------------------------------------
-- Local-only checks for the self-scoped individual billing-account function.
--
-- Run after applying migrations to a LOCAL database only.
-- Never run against the linked production project.
-- ============================================================================

BEGIN;

INSERT INTO core.countries(id, name, iso_alpha2, iso_alpha3, dialing_code)
VALUES ('00000000-0000-0000-0000-000000005001', 'Testland', 'KE', 'KEN', '254');

-- Ensure the canonical owner role exists for core.ensure_entity_for_profile.
DO $test$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM core.user_roles
         WHERE lower(name) = 'owner'
           AND type = 'system'
           AND is_active IS TRUE
    ) THEN
        INSERT INTO core.user_roles (id, name, type, is_active, updated_at)
        VALUES ('00000000-0000-0000-0000-000000005002', 'owner', 'system', true, now());
    END IF;
END;
$test$;

INSERT INTO users.profiles(id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES (
  '00000000-0000-0000-0000-000000005003',
  '00000000-0000-0000-0000-000000005004',
  'Billing Tester',
  '00000000-0000-0000-0000-000000005001',
  true,
  'active'
);

-- Simulate the authenticated caller for auth.uid().
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000005004', true);
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000005004"}', true);

DO $test$
DECLARE
    v_account_id uuid;
    v_entity_id uuid;
    v_profile_id uuid;
    v_account_type text;
    v_currency text;
    v_status text;
    v_count bigint;
    v_retry_id uuid;
BEGIN
    SELECT billing_account_id, entity_id, profile_id, account_type, currency, status
      INTO v_account_id, v_entity_id, v_profile_id, v_account_type, v_currency, v_status
      FROM system.ensure_individual_billing_account();

    IF v_account_id IS NULL THEN
        RAISE EXCEPTION 'billing account id was not returned';
    END IF;
    IF v_profile_id <> '00000000-0000-0000-0000-000000005003' THEN
        RAISE EXCEPTION 'unexpected profile id %', v_profile_id;
    END IF;
    IF v_account_type <> 'individual' OR v_currency <> 'KES' OR v_status <> 'active' THEN
        RAISE EXCEPTION 'unexpected account type/currency/status %/%/%',
            v_account_type, v_currency, v_status;
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM core.entities
         WHERE id = v_entity_id
           AND owner_id = '00000000-0000-0000-0000-000000005003'
           AND entity_type = 'individual_pro'
           AND is_active IS TRUE
    ) THEN
        RAISE EXCEPTION 'billing account entity is not the canonical individual_pro entity';
    END IF;

    SELECT billing_account_id INTO v_retry_id
      FROM system.ensure_individual_billing_account();

    IF v_retry_id <> v_account_id THEN
        RAISE EXCEPTION 'idempotent retry returned a different account';
    END IF;

    SELECT count(*) INTO v_count
      FROM system.billing_accounts
     WHERE profile_id = '00000000-0000-0000-0000-000000005003';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'expected exactly one billing account, found %', v_count;
    END IF;
END;
$test$;

-- Existing non-individual account for the same profile/entity must be rejected.
INSERT INTO users.profiles(id, auth_user_id, first_name, country_id, is_active, account_status)
VALUES (
  '00000000-0000-0000-0000-000000005010',
  '00000000-0000-0000-0000-000000005011',
  'Business Billing Tester',
  '00000000-0000-0000-0000-000000005001',
  true,
  'active'
);

INSERT INTO core.entities(id, name, entity_type, owner_id, is_active, metadata)
VALUES (
  '00000000-0000-0000-0000-000000005012',
  'Business Billing Tester Entity',
  'individual_pro',
  '00000000-0000-0000-0000-000000005010',
  true,
  '{}'::jsonb
);

INSERT INTO system.billing_accounts(entity_id, profile_id, account_type, currency, status)
VALUES (
  '00000000-0000-0000-0000-000000005012',
  '00000000-0000-0000-0000-000000005010',
  'business',
  'KES',
  'active'
);

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000005011', true);
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000005011"}', true);

DO $test$
BEGIN
    BEGIN
        PERFORM system.ensure_individual_billing_account();
        RAISE EXCEPTION 'expected non-individual account rejection';
    EXCEPTION WHEN SQLSTATE '55000' THEN
        NULL;
    END;
END;
$test$;

ROLLBACK;
