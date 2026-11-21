-- Reputation Phase 2C-2 - dedicated processing work ledger.
--
-- Operational state only. This ledger does not store or duplicate engagement,
-- participant, subject, evidence or Commerce business payloads.

BEGIN;

CREATE TABLE reputation.processing_work (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    work_kind text NOT NULL,
    source_system text NOT NULL,
    source_reference text NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    attempt_count integer NOT NULL DEFAULT 0,
    max_attempts integer NOT NULL DEFAULT 5,
    next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    claimed_at timestamptz,
    lease_expires_at timestamptz,
    claim_token uuid,
    claimed_by text,
    last_attempt_at timestamptz,
    last_error_category text,
    last_error_code text,
    last_error_message text,
    dead_letter_reason_code text,
    dead_lettered_at timestamptz,
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT reputation_processing_work_pkey PRIMARY KEY (id),
    CONSTRAINT reputation_processing_work_kind_check
        CHECK (work_kind IN ('stock_order_engagement_ingestion')),
    CONSTRAINT reputation_processing_work_source_system_check
        CHECK (source_system IN ('vunio')),
    CONSTRAINT reputation_processing_work_source_reference_check
        CHECK (btrim(source_reference) <> '' AND length(source_reference) <= 200),
    CONSTRAINT reputation_processing_work_status_check
        CHECK (status IN (
            'pending',
            'processing',
            'retryable',
            'succeeded',
            'dead_letter'
        )),
    CONSTRAINT reputation_processing_work_attempts_check
        CHECK (
            attempt_count >= 0
            AND max_attempts > 0
            AND max_attempts <= 10
            AND attempt_count <= max_attempts
        ),
    CONSTRAINT reputation_processing_work_claim_state_check
        CHECK (
            (
                status = 'processing'
                AND claimed_at IS NOT NULL
                AND lease_expires_at IS NOT NULL
                AND claim_token IS NOT NULL
                AND claimed_by IS NOT NULL
                AND btrim(claimed_by) <> ''
                AND lease_expires_at > claimed_at
            )
            OR
            (
                status <> 'processing'
                AND claimed_at IS NULL
                AND lease_expires_at IS NULL
                AND claim_token IS NULL
                AND claimed_by IS NULL
            )
        ),
    CONSTRAINT reputation_processing_work_terminal_state_check
        CHECK (
            (
                status = 'succeeded'
                AND completed_at IS NOT NULL
                AND dead_lettered_at IS NULL
                AND dead_letter_reason_code IS NULL
            )
            OR
            (
                status = 'dead_letter'
                AND dead_lettered_at IS NOT NULL
                AND btrim(dead_letter_reason_code) <> ''
                AND length(dead_letter_reason_code) <= 100
                AND completed_at IS NULL
            )
            OR
            (
                status IN ('pending', 'processing', 'retryable')
                AND completed_at IS NULL
                AND dead_lettered_at IS NULL
                AND dead_letter_reason_code IS NULL
            )
        ),
    CONSTRAINT reputation_processing_work_pending_count_check
        CHECK (status <> 'pending' OR attempt_count = 0),
    CONSTRAINT reputation_processing_work_success_count_check
        CHECK (status <> 'succeeded' OR attempt_count >= 1),
    CONSTRAINT reputation_processing_work_dead_letter_count_check
        CHECK (status <> 'dead_letter' OR attempt_count >= 1),
    CONSTRAINT reputation_processing_work_retryable_count_check
        CHECK (status <> 'retryable' OR attempt_count < max_attempts),
    CONSTRAINT reputation_processing_work_error_category_check
        CHECK (
            last_error_category IS NULL
            OR last_error_category IN (
                'transient_technical',
                'ineligible_business',
                'source_conflict',
                'unexpected_permanent'
            )
        ),
    CONSTRAINT reputation_processing_work_error_code_check
        CHECK (
            last_error_code IS NULL
            OR (btrim(last_error_code) <> '' AND length(last_error_code) <= 100)
        ),
    CONSTRAINT reputation_processing_work_error_message_check
        CHECK (last_error_message IS NULL OR length(last_error_message) <= 1000),
    CONSTRAINT reputation_processing_work_retryable_error_check
        CHECK (
            status <> 'retryable'
            OR (last_error_category IS NOT NULL AND last_error_code IS NOT NULL)
        ),
    CONSTRAINT reputation_processing_work_success_error_check
        CHECK (
            status <> 'succeeded'
            OR (
                last_error_category IS NULL
                AND last_error_code IS NULL
                AND last_error_message IS NULL
            )
        ),
    CONSTRAINT reputation_processing_work_timestamp_order_check
        CHECK (
            updated_at >= created_at
            AND (claimed_at IS NULL OR claimed_at >= created_at)
            AND (last_attempt_at IS NULL OR last_attempt_at >= created_at)
            AND (completed_at IS NULL OR completed_at >= created_at)
            AND (dead_lettered_at IS NULL OR dead_lettered_at >= created_at)
        )
);

ALTER TABLE reputation.processing_work OWNER TO postgres;
ALTER TABLE reputation.processing_work ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX reputation_processing_work_identity_uidx
    ON reputation.processing_work (
        work_kind,
        source_system,
        source_reference
    );

CREATE INDEX reputation_processing_work_claim_idx
    ON reputation.processing_work (status, next_attempt_at, created_at, id)
    WHERE status IN ('pending', 'retryable');

CREATE INDEX reputation_processing_work_lease_idx
    ON reputation.processing_work (lease_expires_at)
    WHERE status = 'processing';

CREATE INDEX reputation_processing_work_status_idx
    ON reputation.processing_work (status, updated_at DESC);

COMMENT ON TABLE reputation.processing_work IS
    'Durable operational work state for Reputation processing. Not business truth.';

COMMENT ON COLUMN reputation.processing_work.source_reference IS
    'Immutable source identity; for stock-order ingestion this is commerce.orders.id::text.';

COMMENT ON COLUMN reputation.processing_work.claim_token IS
    'Fresh token on every claim/reclaim; only the current token may complete the work.';

CREATE TABLE reputation.processing_attempts (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    work_id uuid NOT NULL,
    attempt_number integer NOT NULL,
    claim_token uuid NOT NULL,
    worker_id text NOT NULL,
    run_id text,
    started_at timestamptz NOT NULL,
    finished_at timestamptz NOT NULL,
    outcome text NOT NULL,
    error_category text,
    error_code text,
    error_message text,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT reputation_processing_attempts_pkey PRIMARY KEY (id),
    CONSTRAINT reputation_processing_attempts_work_id_fkey
        FOREIGN KEY (work_id) REFERENCES reputation.processing_work(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_processing_attempts_number_check
        CHECK (attempt_number > 0),
    CONSTRAINT reputation_processing_attempts_worker_id_check
        CHECK (btrim(worker_id) <> '' AND length(worker_id) <= 200),
    CONSTRAINT reputation_processing_attempts_run_id_check
        CHECK (run_id IS NULL OR length(run_id) <= 200),
    CONSTRAINT reputation_processing_attempts_time_check
        CHECK (finished_at >= started_at),
    CONSTRAINT reputation_processing_attempts_outcome_check
        CHECK (outcome IN ('succeeded', 'retryable', 'dead_letter')),
    CONSTRAINT reputation_processing_attempts_error_category_check
        CHECK (
            error_category IS NULL
            OR error_category IN (
                'transient_technical',
                'ineligible_business',
                'source_conflict',
                'unexpected_permanent'
            )
        ),
    CONSTRAINT reputation_processing_attempts_error_code_check
        CHECK (
            error_code IS NULL
            OR (btrim(error_code) <> '' AND length(error_code) <= 100)
        ),
    CONSTRAINT reputation_processing_attempts_error_message_check
        CHECK (error_message IS NULL OR length(error_message) <= 1000),
    CONSTRAINT reputation_processing_attempts_outcome_error_check
        CHECK (
            (
                outcome = 'succeeded'
                AND error_category IS NULL
                AND error_code IS NULL
                AND error_message IS NULL
            )
            OR
            (
                outcome IN ('retryable', 'dead_letter')
                AND error_category IS NOT NULL
                AND error_code IS NOT NULL
            )
        )
);

ALTER TABLE reputation.processing_attempts OWNER TO postgres;
ALTER TABLE reputation.processing_attempts ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX reputation_processing_attempts_number_uidx
    ON reputation.processing_attempts (work_id, attempt_number);

CREATE INDEX reputation_processing_attempts_work_finished_idx
    ON reputation.processing_attempts (work_id, finished_at DESC);

COMMENT ON TABLE reputation.processing_attempts IS
    'Append-only completed-attempt history for the Reputation processing ledger.';

CREATE OR REPLACE FUNCTION reputation.reject_processing_attempt_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
BEGIN
    RAISE EXCEPTION 'Reputation processing attempts are append-only: %.%',
        TG_TABLE_SCHEMA, TG_TABLE_NAME
        USING ERRCODE = '42501';
END;
$function$;

ALTER FUNCTION reputation.reject_processing_attempt_mutation()
    OWNER TO postgres;

CREATE TRIGGER reputation_processing_attempts_append_only
    BEFORE UPDATE OR DELETE ON reputation.processing_attempts
    FOR EACH ROW
    EXECUTE FUNCTION reputation.reject_processing_attempt_mutation();

CREATE TRIGGER reputation_processing_attempts_no_truncate
    BEFORE TRUNCATE ON reputation.processing_attempts
    FOR EACH STATEMENT
    EXECUTE FUNCTION reputation.reject_processing_attempt_mutation();

CREATE OR REPLACE FUNCTION reputation.guard_processing_work_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.work_kind IS DISTINCT FROM OLD.work_kind
       OR NEW.source_system IS DISTINCT FROM OLD.source_system
       OR NEW.source_reference IS DISTINCT FROM OLD.source_reference
       OR NEW.max_attempts IS DISTINCT FROM OLD.max_attempts
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Processing work identity and creation limits are immutable'
            USING ERRCODE = '23514';
    END IF;

    IF OLD.status IN ('succeeded', 'dead_letter') THEN
        RAISE EXCEPTION 'Processing work is terminal'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.updated_at < OLD.updated_at THEN
        RAISE EXCEPTION 'Processing work updated_at cannot move backwards'
            USING ERRCODE = '23514';
    END IF;

    IF OLD.status IN ('pending', 'retryable')
       AND NEW.status = 'processing' THEN
        IF NEW.attempt_count <> OLD.attempt_count + 1 THEN
            RAISE EXCEPTION 'Claim must increment attempt_count by exactly one'
                USING ERRCODE = '23514';
        END IF;
    ELSIF OLD.status = 'processing' AND NEW.status = 'processing' THEN
        IF NEW.attempt_count <> OLD.attempt_count + 1 THEN
            RAISE EXCEPTION 'Reclaim must increment attempt_count by exactly one'
                USING ERRCODE = '23514';
        END IF;
    ELSIF OLD.status = 'processing'
          AND NEW.status IN ('succeeded', 'retryable', 'dead_letter') THEN
        IF NEW.attempt_count <> OLD.attempt_count THEN
            RAISE EXCEPTION 'Completion must not change attempt_count'
                USING ERRCODE = '23514';
        END IF;
    ELSIF OLD.status = 'retryable' AND NEW.status = 'dead_letter' THEN
        IF NEW.attempt_count <> OLD.attempt_count THEN
            RAISE EXCEPTION 'Retry exhaustion must not change attempt_count'
                USING ERRCODE = '23514';
        END IF;
    ELSE
        RAISE EXCEPTION 'Invalid processing work transition: % -> %',
            OLD.status, NEW.status
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

ALTER FUNCTION reputation.guard_processing_work_transition()
    OWNER TO postgres;

CREATE TRIGGER reputation_processing_work_guard
    BEFORE UPDATE ON reputation.processing_work
    FOR EACH ROW
    EXECUTE FUNCTION reputation.guard_processing_work_transition();

-- ---------------------------------------------------------------------------
-- Private trusted operations.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.enqueue_stock_order_engagement_work(
    p_order_id uuid
)
RETURNS TABLE (
    work_id uuid,
    status text,
    created boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_now timestamptz := clock_timestamp();
    v_work_id uuid;
    v_status text;
BEGIN
    IF p_order_id IS NULL THEN
        RAISE EXCEPTION 'Order id is required'
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO reputation.processing_work AS w (
        work_kind,
        source_system,
        source_reference,
        status,
        next_attempt_at,
        created_at,
        updated_at
    ) VALUES (
        'stock_order_engagement_ingestion',
        'vunio',
        p_order_id::text,
        'pending',
        v_now,
        v_now,
        v_now
    )
    ON CONFLICT (work_kind, source_system, source_reference) DO NOTHING
    RETURNING w.id, w.status INTO v_work_id, v_status;

    IF v_work_id IS NOT NULL THEN
        RETURN QUERY SELECT v_work_id, v_status, true;
        RETURN;
    END IF;

    SELECT w.id, w.status
      INTO v_work_id, v_status
      FROM reputation.processing_work AS w
     WHERE w.work_kind = 'stock_order_engagement_ingestion'
       AND w.source_system = 'vunio'
       AND w.source_reference = p_order_id::text;

    RETURN QUERY SELECT v_work_id, v_status, false;
END;
$function$;

ALTER FUNCTION reputation.enqueue_stock_order_engagement_work(uuid)
    OWNER TO postgres;

CREATE OR REPLACE FUNCTION reputation.claim_processing_work(
    p_limit integer,
    p_worker_id text,
    p_lease_seconds integer
)
RETURNS TABLE (
    work_id uuid,
    work_kind text,
    source_system text,
    source_reference text,
    attempt_number integer,
    claim_token uuid,
    lease_expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_now timestamptz := clock_timestamp();
    v_worker_id text;
BEGIN
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
        RAISE EXCEPTION 'Claim limit must be between 1 and 100'
            USING ERRCODE = '22023';
    END IF;

    v_worker_id := btrim(COALESCE(p_worker_id, ''));
    IF v_worker_id = '' OR length(v_worker_id) > 200 THEN
        RAISE EXCEPTION 'worker_id is required and must be at most 200 characters'
            USING ERRCODE = '22023';
    END IF;

    IF p_lease_seconds IS NULL OR p_lease_seconds < 1 OR p_lease_seconds > 3600 THEN
        RAISE EXCEPTION 'lease_seconds must be between 1 and 3600'
            USING ERRCODE = '22023';
    END IF;

    -- Retry-budget exhaustion is terminal and must not consume another claim.
    UPDATE reputation.processing_work AS w
       SET status = 'dead_letter',
           dead_letter_reason_code = 'retry_budget_exhausted',
           dead_lettered_at = v_now,
           claimed_at = NULL,
           lease_expires_at = NULL,
           claim_token = NULL,
           claimed_by = NULL,
           completed_at = NULL,
           next_attempt_at = v_now,
           updated_at = v_now
     WHERE w.attempt_count >= w.max_attempts
       AND (
           w.status = 'retryable'
           OR (
               w.status = 'processing'
               AND w.lease_expires_at <= v_now
           )
       );

    RETURN QUERY
    WITH candidate AS (
        SELECT w.id
          FROM reputation.processing_work AS w
         WHERE w.attempt_count < w.max_attempts
           AND (
               (
                   w.status IN ('pending', 'retryable')
                   AND w.next_attempt_at <= v_now
               )
               OR (
                   w.status = 'processing'
                   AND w.lease_expires_at <= v_now
               )
           )
         ORDER BY w.next_attempt_at, w.created_at, w.id
         FOR UPDATE SKIP LOCKED
         LIMIT p_limit
    )
    UPDATE reputation.processing_work AS w
       SET status = 'processing',
           attempt_count = w.attempt_count + 1,
           claimed_at = v_now,
           lease_expires_at = v_now + make_interval(secs => p_lease_seconds),
           claim_token = gen_random_uuid(),
           claimed_by = v_worker_id,
           last_attempt_at = v_now,
           updated_at = v_now
      FROM candidate AS c
     WHERE w.id = c.id
     RETURNING
        w.id,
        w.work_kind,
        w.source_system,
        w.source_reference,
        w.attempt_count,
        w.claim_token,
        w.lease_expires_at;
END;
$function$;

ALTER FUNCTION reputation.claim_processing_work(integer, text, integer)
    OWNER TO postgres;

CREATE OR REPLACE FUNCTION reputation.complete_processing_work(
    p_work_id uuid,
    p_claim_token uuid,
    p_outcome text,
    p_error_category text DEFAULT NULL,
    p_error_code text DEFAULT NULL,
    p_error_message text DEFAULT NULL,
    p_run_id text DEFAULT NULL
)
RETURNS TABLE (
    work_id uuid,
    status text,
    attempt_count integer,
    next_attempt_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_now timestamptz := clock_timestamp();
    v_work reputation.processing_work%ROWTYPE;
    v_new_status text;
    v_attempt_outcome text;
    v_dead_letter_reason text;
    v_error_code text;
    v_error_message text;
    v_next_attempt_at timestamptz;
BEGIN
    IF p_work_id IS NULL OR p_claim_token IS NULL THEN
        RAISE EXCEPTION 'work_id and claim_token are required'
            USING ERRCODE = '22023';
    END IF;

    IF p_outcome NOT IN ('succeeded', 'retryable', 'dead_letter') THEN
        RAISE EXCEPTION 'Invalid completion outcome'
            USING ERRCODE = '22023';
    END IF;

    IF p_error_category IS NOT NULL
       AND p_error_category NOT IN (
           'transient_technical',
           'ineligible_business',
           'source_conflict',
           'unexpected_permanent'
       ) THEN
        RAISE EXCEPTION 'Invalid error category'
            USING ERRCODE = '22023';
    END IF;

    v_error_code := NULLIF(btrim(COALESCE(p_error_code, '')), '');
    v_error_message := NULLIF(btrim(COALESCE(p_error_message, '')), '');

    IF p_outcome IN ('retryable', 'dead_letter') THEN
        IF p_error_category IS NULL OR v_error_code IS NULL THEN
            RAISE EXCEPTION 'Error category and code are required for failed work'
                USING ERRCODE = '22023';
        END IF;

        IF length(v_error_code) > 100 THEN
            RAISE EXCEPTION 'Error code must be at most 100 characters'
                USING ERRCODE = '22023';
        END IF;
    END IF;

    SELECT w.*
      INTO v_work
      FROM reputation.processing_work AS w
     WHERE w.id = p_work_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Processing work not found'
            USING ERRCODE = 'P0002';
    END IF;

    IF v_work.status <> 'processing'
       OR v_work.claim_token IS DISTINCT FROM p_claim_token THEN
        RAISE EXCEPTION 'Claim token is stale or work is not processing'
            USING ERRCODE = '55000';
    END IF;

    IF p_outcome = 'succeeded' THEN
        v_new_status := 'succeeded';
        v_attempt_outcome := 'succeeded';
        v_dead_letter_reason := NULL;
        v_next_attempt_at := v_now;
        v_error_code := NULL;
        v_error_message := NULL;
    ELSIF p_outcome = 'retryable' THEN
        IF v_work.attempt_count < v_work.max_attempts THEN
            v_new_status := 'retryable';
            v_attempt_outcome := 'retryable';
            v_dead_letter_reason := NULL;
            v_next_attempt_at := v_now + make_interval(
                mins => least(
                    60,
                    (2 ^ (v_work.attempt_count - 1))::integer
                )
            );
        ELSE
            v_new_status := 'dead_letter';
            v_attempt_outcome := 'dead_letter';
            v_dead_letter_reason := 'retry_budget_exhausted';
            v_next_attempt_at := v_now;
        END IF;
    ELSE
        v_new_status := 'dead_letter';
        v_attempt_outcome := 'dead_letter';
        v_dead_letter_reason := v_error_code;
        v_next_attempt_at := v_now;
    END IF;

    UPDATE reputation.processing_work AS w
       SET status = v_new_status,
           claimed_at = NULL,
           lease_expires_at = NULL,
           claim_token = NULL,
           claimed_by = NULL,
           completed_at = CASE
               WHEN v_new_status = 'succeeded' THEN v_now
               ELSE NULL
           END,
           dead_lettered_at = CASE
               WHEN v_new_status = 'dead_letter' THEN v_now
               ELSE NULL
           END,
           dead_letter_reason_code = CASE
               WHEN v_new_status = 'dead_letter' THEN v_dead_letter_reason
               ELSE NULL
           END,
           last_error_category = CASE
               WHEN p_outcome = 'succeeded' THEN NULL
               ELSE p_error_category
           END,
           last_error_code = CASE
               WHEN p_outcome = 'succeeded' THEN NULL
               ELSE v_error_code
           END,
           last_error_message = CASE
               WHEN p_outcome = 'succeeded' THEN NULL
               ELSE left(v_error_message, 1000)
           END,
           next_attempt_at = v_next_attempt_at,
           updated_at = v_now
     WHERE w.id = v_work.id;

    INSERT INTO reputation.processing_attempts (
        work_id,
        attempt_number,
        claim_token,
        worker_id,
        run_id,
        started_at,
        finished_at,
        outcome,
        error_category,
        error_code,
        error_message
    ) VALUES (
        v_work.id,
        v_work.attempt_count,
        p_claim_token,
        v_work.claimed_by,
        left(NULLIF(btrim(COALESCE(p_run_id, '')), ''), 200),
        v_work.claimed_at,
        v_now,
        v_attempt_outcome,
        CASE WHEN p_outcome = 'succeeded' THEN NULL ELSE p_error_category END,
        CASE WHEN p_outcome = 'succeeded' THEN NULL ELSE left(v_error_code, 100) END,
        CASE WHEN p_outcome = 'succeeded' THEN NULL ELSE left(v_error_message, 1000) END
    );

    RETURN QUERY SELECT
        v_work.id,
        v_new_status,
        v_work.attempt_count,
        v_next_attempt_at;
END;
$function$;

ALTER FUNCTION reputation.complete_processing_work(
    uuid, uuid, text, text, text, text, text
) OWNER TO postgres;

COMMENT ON FUNCTION reputation.enqueue_stock_order_engagement_work(uuid) IS
    'Idempotently enqueues stock-order engagement processing work without reading Commerce.';
COMMENT ON FUNCTION reputation.claim_processing_work(integer, text, integer) IS
    'Claims due work with FOR UPDATE SKIP LOCKED, lease tokens, and retry-budget exhaustion.';
COMMENT ON FUNCTION reputation.complete_processing_work(
    uuid, uuid, text, text, text, text, text
) IS
    'Completes or retries claimed work with an append-only attempt history.';

-- ---------------------------------------------------------------------------
-- Privileges. Ledger access is function-only.
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE reputation.processing_work
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.processing_attempts
    FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION reputation.reject_processing_attempt_mutation()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.guard_processing_work_transition()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.enqueue_stock_order_engagement_work(uuid)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.claim_processing_work(integer, text, integer)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.complete_processing_work(
    uuid, uuid, text, text, text, text, text
)
    FROM PUBLIC, anon, authenticated, service_role;

COMMIT;
