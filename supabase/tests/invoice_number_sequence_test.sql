-- ============================================================================
-- invoice_number_sequence_test.sql
-- ----------------------------------------------------------------------------
-- Local-only checks for the technical invoice-number sequence allocator.
--
-- Run after applying migrations to a LOCAL database only.
-- Never run against the linked production project.
-- ============================================================================

BEGIN;

DO $test$
DECLARE
    v_first text;
    v_second text;
BEGIN
    v_first := system.allocate_invoice_number();
    v_second := system.allocate_invoice_number();

    IF v_first IS NULL OR btrim(v_first) = '' THEN
        RAISE EXCEPTION 'first invoice allocation was empty';
    END IF;
    IF v_second IS NULL OR btrim(v_second) = '' THEN
        RAISE EXCEPTION 'second invoice allocation was empty';
    END IF;
    IF v_first = v_second THEN
        RAISE EXCEPTION 'invoice allocations were not unique';
    END IF;
    IF v_second::bigint <= v_first::bigint THEN
        RAISE EXCEPTION 'invoice allocation did not increase: % then %', v_first, v_second;
    END IF;
END;
$test$;

ROLLBACK;
