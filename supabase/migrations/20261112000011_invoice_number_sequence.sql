-- ============================================================================
-- 20261112000011_invoice_number_sequence
-- ----------------------------------------------------------------------------
-- PURPOSE
--   Provide the smallest server-side authoritative invoice-number allocator
--   when no existing database generator is present.
--
-- LIVE FACTS RESPECTED
--   * system.invoices.invoice_number has no default.
--   * There is no invoice-number function, trigger or sequence live.
--   * system.invoices currently has zero rows.
--
-- DESIGN BOUNDARY
--   This is a TECHNICAL NUMERIC ALLOCATOR, not a business-facing invoice
--   format. It uses a PostgreSQL sequence and returns only the decimal
--   sequence value as text. No prefix, tenant code, year code or random
--   component is invented.
--
--   A business-facing invoice-number format remains an explicit future
--   decision. Until then, finance.create_annual_subscription still requires
--   the caller to supply p_invoice_number.
--
-- SECURITY
--   Service-role only. No client execute grant. The underlying sequence is
--   not directly accessible to client roles.
--
-- ROLLBACK
--   DROP FUNCTION IF EXISTS system.allocate_invoice_number();
--   DROP SEQUENCE IF EXISTS system.invoice_number_seq;
-- ============================================================================

BEGIN;

CREATE SEQUENCE IF NOT EXISTS "system"."invoice_number_seq"
    AS bigint
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    START WITH 1
    CACHE 1;

CREATE OR REPLACE FUNCTION "system"."allocate_invoice_number"()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, system
AS $function$
    SELECT nextval('system.invoice_number_seq')::text
$function$;

REVOKE ALL ON SEQUENCE "system"."invoice_number_seq"
    FROM PUBLIC, "anon", "authenticated", "service_role";

REVOKE ALL ON FUNCTION "system"."allocate_invoice_number"()
    FROM PUBLIC, "anon", "authenticated";
GRANT EXECUTE ON FUNCTION "system"."allocate_invoice_number"()
    TO "service_role";

COMMENT ON SEQUENCE "system"."invoice_number_seq"
    IS 'Technical invoice-number sequence. Business-facing formatting is not defined.';

COMMENT ON FUNCTION "system"."allocate_invoice_number"()
    IS 'Server-side concurrency-safe decimal invoice-number allocation. No prefix or business format is invented.';

COMMIT;
