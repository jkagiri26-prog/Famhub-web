-- ============================================================================
-- reputation_processing_work_ledger_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE functional test for Phase 2C-2.
--
-- Run only against a local/disposable database with all migrations applied.
-- Never run against production.
-- ============================================================================
BEGIN;

DO $schema$
DECLARE
    v_rls boolean;
BEGIN
    IF to_regclass('reputation.processing_work') IS NULL
       OR to_regclass('reputation.processing_attempts') IS NULL THEN
        RAISE EXCEPTION 'Phase 2C-2 work ledger tables are missing';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname='reputation'
           AND c.relname IN ('processing_work','processing_attempts')
           AND pg_get_userbyid(c.relowner) <> 'postgres'
    ) THEN
        RAISE EXCEPTION 'Work ledger owner is not postgres';
    END IF;

    SELECT relrowsecurity INTO v_rls
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='reputation' AND c.relname='processing_work';
    IF v_rls IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'processing_work RLS is not enabled';
    END IF;

    SELECT relrowsecurity INTO v_rls
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='reputation' AND c.relname='processing_attempts';
    IF v_rls IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'processing_attempts RLS is not enabled';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_policies
         WHERE schemaname='reputation'
           AND tablename IN ('processing_work','processing_attempts')
    ) THEN
        RAISE EXCEPTION 'unexpected work ledger policies exist';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM (VALUES ('anon'), ('authenticated'), ('service_role')) AS r(role_name)
          CROSS JOIN (VALUES ('reputation.processing_work'),
                             ('reputation.processing_attempts')) AS t(table_name)
          CROSS JOIN (VALUES ('SELECT'), ('INSERT'), ('UPDATE'),
                             ('DELETE'), ('TRUNCATE')) AS c(command_name)
         WHERE has_table_privilege(r.role_name, t.table_name, c.command_name)
    ) THEN
        RAISE EXCEPTION 'API role has direct work ledger access';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='reputation'
           AND p.proname='enqueue_stock_order_engagement_work'
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.prosecdef = true
           AND p.proconfig @> ARRAY['search_path=pg_catalog, reputation']
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='reputation'
           AND p.proname='claim_processing_work'
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.prosecdef = true
           AND p.proconfig @> ARRAY['search_path=pg_catalog, reputation']
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='reputation'
           AND p.proname='complete_processing_work'
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.prosecdef = true
           AND p.proconfig @> ARRAY['search_path=pg_catalog, reputation']
    ) THEN
        RAISE EXCEPTION 'Private work ledger function security properties are wrong';
    END IF;

    IF has_function_privilege(
           'service_role',
           'reputation.enqueue_stock_order_engagement_work(uuid)',
           'EXECUTE')
       OR has_function_privilege(
           'service_role',
           'reputation.claim_processing_work(integer,text,integer)',
           'EXECUTE')
       OR has_function_privilege(
           'service_role',
           'reputation.complete_processing_work(uuid,uuid,text,text,text,text,text)',
           'EXECUTE')
       OR has_function_privilege(
           'authenticated',
           'reputation.claim_processing_work(integer,text,integer)',
           'EXECUTE')
       OR has_function_privilege(
           'anon',
           'reputation.complete_processing_work(uuid,uuid,text,text,text,text,text)',
           'EXECUTE')
       OR EXISTS (
           SELECT 1
             FROM pg_proc p
             JOIN pg_namespace n ON n.oid=p.pronamespace
             CROSS JOIN LATERAL aclexplode(p.proacl) AS a
            WHERE n.nspname='reputation'
              AND p.proname IN ('enqueue_stock_order_engagement_work',
                                'claim_processing_work',
                                'complete_processing_work')
              AND a.grantee=0
              AND a.privilege_type='EXECUTE'
       ) THEN
        RAISE EXCEPTION 'Private work ledger function is executable by an API role or PUBLIC';
    END IF;

    IF NOT has_function_privilege(
           'service_role',
           'system.enqueue_reputation_stock_order_work(uuid)',
           'EXECUTE')
       OR NOT has_function_privilege(
           'service_role',
           'system.claim_reputation_processing_work(integer,text,integer)',
           'EXECUTE')
       OR NOT has_function_privilege(
           'service_role',
           'system.complete_reputation_processing_work(uuid,uuid,text,text,text,text,text)',
           'EXECUTE')
       OR has_function_privilege(
           'authenticated',
           'system.enqueue_reputation_stock_order_work(uuid)',
           'EXECUTE')
       OR has_function_privilege(
           'anon',
           'system.claim_reputation_processing_work(integer,text,integer)',
           'EXECUTE')
       OR has_function_privilege(
           'anon',
           'system.enqueue_reputation_stock_order_work(uuid)',
           'EXECUTE')
       OR has_function_privilege(
           'authenticated',
           'system.claim_reputation_processing_work(integer,text,integer)',
           'EXECUTE')
       OR has_function_privilege(
           'anon',
           'system.complete_reputation_processing_work(uuid,uuid,text,text,text,text,text)',
           'EXECUTE')
       OR has_function_privilege(
           'authenticated',
           'system.complete_reputation_processing_work(uuid,uuid,text,text,text,text,text)',
           'EXECUTE')
       OR EXISTS (
           SELECT 1
             FROM pg_proc p
             JOIN pg_namespace n ON n.oid=p.pronamespace
             CROSS JOIN LATERAL aclexplode(p.proacl) AS a
            WHERE n.nspname='system'
              AND p.proname IN ('enqueue_reputation_stock_order_work',
                                'claim_reputation_processing_work',
                                'complete_reputation_processing_work')
              AND a.grantee=0
              AND a.privilege_type='EXECUTE'
       ) THEN
        RAISE EXCEPTION 'Work ledger gateway grants are wrong';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='system'
           AND p.proname IN ('enqueue_reputation_stock_order_work',
                             'claim_reputation_processing_work',
                             'complete_reputation_processing_work')
           AND p.prosecdef=true
           AND pg_get_userbyid(p.proowner)='postgres'
           AND p.proconfig @> ARRAY['search_path=pg_catalog, system, reputation']
    ) OR (
        SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='system'
           AND p.proname IN ('enqueue_reputation_stock_order_work',
                             'claim_reputation_processing_work',
                             'complete_reputation_processing_work')
    ) <> 3 THEN
        RAISE EXCEPTION 'Gateway security properties are wrong';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE (
             (n.nspname='reputation'
              AND p.proname IN ('enqueue_stock_order_engagement_work',
                                'claim_processing_work',
                                'complete_processing_work'))
             OR
             (n.nspname='system'
              AND p.proname IN ('enqueue_reputation_stock_order_work',
                                'claim_reputation_processing_work',
                                'complete_reputation_processing_work'))
         )
           AND p.prosrc LIKE '%current_setting%'
    ) THEN
        RAISE EXCEPTION 'Phase 2C-2 function has custom GUC dependency';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger t
          JOIN pg_class c ON c.oid=t.tgrelid
          JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='reputation' AND c.relname='processing_attempts'
           AND t.tgname='reputation_processing_attempts_append_only'
           AND pg_get_triggerdef(t.oid) LIKE '%BEFORE DELETE OR UPDATE%'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger t
          JOIN pg_class c ON c.oid=t.tgrelid
          JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='reputation' AND c.relname='processing_attempts'
           AND t.tgname='reputation_processing_attempts_no_truncate'
           AND pg_get_triggerdef(t.oid) LIKE '%BEFORE TRUNCATE%'
           AND pg_get_triggerdef(t.oid) LIKE '%FOR EACH STATEMENT%'
    ) THEN
        RAISE EXCEPTION 'Attempt append-only/truncate protection is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
         WHERE schemaname='reputation'
           AND indexname='reputation_processing_work_identity_uidx'
    ) THEN
        RAISE EXCEPTION 'Work identity unique index is missing';
    END IF;
END;
$schema$;

DO $creation$
DECLARE
    v_result record;
    v_work_id uuid;
    v_count integer;
    v_exists boolean;
BEGIN
    IF to_regclass('commerce.orders') IS NOT NULL THEN
        EXECUTE
            'SELECT EXISTS (SELECT 1 FROM commerce.orders WHERE id::text = $1)'
          INTO v_exists
         USING 'a1000000-0000-4000-8000-000000000001';
        IF v_exists THEN
            RAISE EXCEPTION 'Test order unexpectedly exists in Commerce';
        END IF;
    END IF;

    SELECT * INTO v_result
      FROM system.enqueue_reputation_stock_order_work(
          'a1000000-0000-4000-8000-000000000001'
      );

    IF v_result.created IS DISTINCT FROM true
       OR v_result.status <> 'pending' THEN
        RAISE EXCEPTION 'Initial enqueue failed';
    END IF;
    v_work_id := v_result.work_id;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_work w
         WHERE w.id=v_work_id
           AND w.work_kind='stock_order_engagement_ingestion'
           AND w.source_system='vunio'
           AND w.source_reference='a1000000-0000-4000-8000-000000000001'
           AND w.status='pending'
           AND w.attempt_count=0
           AND w.max_attempts=5
           AND w.next_attempt_at <= clock_timestamp()
           AND w.claimed_at IS NULL
           AND w.lease_expires_at IS NULL
           AND w.claim_token IS NULL
           AND w.claimed_by IS NULL
           AND w.last_attempt_at IS NULL
           AND w.completed_at IS NULL
           AND w.dead_lettered_at IS NULL
           AND w.dead_letter_reason_code IS NULL
    ) THEN
        RAISE EXCEPTION 'Initial work identity/state mismatch';
    END IF;

    SELECT * INTO v_result
      FROM system.enqueue_reputation_stock_order_work(
          'a1000000-0000-4000-8000-000000000001'
      );
    IF v_result.created IS DISTINCT FROM false
       OR v_result.work_id <> v_work_id
       OR v_result.status <> 'pending' THEN
        RAISE EXCEPTION 'Duplicate enqueue was not idempotent';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.processing_work
     WHERE source_reference='a1000000-0000-4000-8000-000000000001';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Duplicate enqueue created multiple work rows';
    END IF;
END;
$creation$;

DO $success$
DECLARE
    v_work_id uuid;
    v_claim record;
    v_result record;
    v_count integer;
BEGIN
    SELECT id INTO v_work_id
      FROM reputation.processing_work
     WHERE source_reference='a1000000-0000-4000-8000-000000000001';

    SELECT * INTO v_claim
      FROM system.claim_reputation_processing_work(1, 'worker-success', 300);

    IF v_claim.work_id <> v_work_id
       OR v_claim.work_kind <> 'stock_order_engagement_ingestion'
       OR v_claim.source_system <> 'vunio'
       OR v_claim.source_reference <> 'a1000000-0000-4000-8000-000000000001'
       OR v_claim.attempt_number <> 1
       OR v_claim.claim_token IS NULL
       OR v_claim.lease_expires_at <= clock_timestamp() THEN
        RAISE EXCEPTION 'Pending claim result mismatch';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.processing_attempts
     WHERE work_id=v_work_id;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Claim incorrectly created an in-progress attempt row';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_work w
         WHERE w.id=v_work_id
           AND w.status='processing'
           AND w.attempt_count=1
           AND w.claimed_by='worker-success'
           AND w.claimed_at IS NOT NULL
           AND w.lease_expires_at IS NOT NULL
           AND w.claim_token=v_claim.claim_token
           AND w.last_attempt_at IS NOT NULL
           AND w.last_attempt_at >= w.claimed_at
    ) THEN
        RAISE EXCEPTION 'Claim state was not persisted correctly';
    END IF;

    SELECT count(*) INTO v_count
      FROM system.claim_reputation_processing_work(1, 'worker-second', 300);
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Second worker claimed work under an active lease';
    END IF;

    SELECT * INTO v_result
      FROM system.complete_reputation_processing_work(
          v_work_id, v_claim.claim_token, 'succeeded'
      );

    IF v_result.status <> 'succeeded'
       OR v_result.attempt_count <> 1 THEN
        RAISE EXCEPTION 'Success completion result mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_work w
         WHERE w.id=v_work_id
           AND w.status='succeeded'
           AND w.completed_at IS NOT NULL
           AND w.claimed_at IS NULL
           AND w.lease_expires_at IS NULL
           AND w.claim_token IS NULL
           AND w.claimed_by IS NULL
           AND w.last_error_category IS NULL
    ) THEN
        RAISE EXCEPTION 'Succeeded work row state mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_attempts a
         WHERE a.work_id=v_work_id
           AND a.attempt_number=1
           AND a.outcome='succeeded'
           AND a.error_category IS NULL
           AND a.error_code IS NULL
           AND a.error_message IS NULL
    ) THEN
        RAISE EXCEPTION 'Succeeded attempt history missing or wrong';
    END IF;

    SELECT * INTO v_result
      FROM system.enqueue_reputation_stock_order_work(
          'a1000000-0000-4000-8000-000000000001'
      );
    IF v_result.created IS DISTINCT FROM false
       OR v_result.status <> 'succeeded'
       OR v_result.work_id <> v_work_id THEN
        RAISE EXCEPTION 'Enqueue reopened succeeded work';
    END IF;
END;
$success$;

DO $retryable$
DECLARE
    v_result record;
    v_work_id uuid;
    v_claim record;
    v_count integer;
BEGIN
    SELECT * INTO v_result
      FROM system.enqueue_reputation_stock_order_work(
          'a1000000-0000-4000-8000-000000000002'
      );
    v_work_id := v_result.work_id;

    SELECT * INTO v_claim
      FROM system.claim_reputation_processing_work(1, 'worker-retry', 300);
    IF v_claim.work_id <> v_work_id OR v_claim.attempt_number <> 1 THEN
        RAISE EXCEPTION 'Retry fixture claim mismatch';
    END IF;

    SELECT * INTO v_result
      FROM system.complete_reputation_processing_work(
          v_work_id,
          v_claim.claim_token,
          'retryable',
          'transient_technical',
          'gateway_timeout',
          'temporary gateway timeout'
      );

    IF v_result.status <> 'retryable'
       OR v_result.attempt_count <> 1
       OR v_result.next_attempt_at <= clock_timestamp() THEN
        RAISE EXCEPTION 'Retryable completion result mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_work w
         WHERE w.id=v_work_id
           AND w.status='retryable'
           AND w.claimed_at IS NULL
           AND w.lease_expires_at IS NULL
           AND w.claim_token IS NULL
           AND w.claimed_by IS NULL
           AND w.last_error_category='transient_technical'
           AND w.last_error_code='gateway_timeout'
           AND w.next_attempt_at > clock_timestamp()
    ) THEN
        RAISE EXCEPTION 'Retryable work row state mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_attempts a
         WHERE a.work_id=v_work_id
           AND a.attempt_number=1
           AND a.outcome='retryable'
           AND a.error_category='transient_technical'
           AND a.error_code='gateway_timeout'
    ) THEN
        RAISE EXCEPTION 'Retryable attempt history missing or wrong';
    END IF;

    SELECT count(*) INTO v_count
      FROM system.claim_reputation_processing_work(1, 'worker-future', 300);
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Future retryable work was claimed too early';
    END IF;
END;
$retryable$;

DO $exhaustion$
DECLARE
    v_result record;
    v_work_id uuid;
    v_claim record;
    v_token uuid;
    v_i integer;
    v_count integer;
BEGIN
    SELECT * INTO v_result
      FROM system.enqueue_reputation_stock_order_work(
          'a1000000-0000-4000-8000-000000000003'
      );
    v_work_id := v_result.work_id;

    FOR v_i IN 1..5 LOOP
        IF v_i > 1 THEN
            PERFORM pg_sleep(1.1);
        END IF;

        SELECT * INTO v_claim
          FROM system.claim_reputation_processing_work(1, 'worker-exhaust', 1);

        IF v_claim.work_id <> v_work_id
           OR v_claim.attempt_number <> v_i THEN
            RAISE EXCEPTION 'Exhaustion claim mismatch at attempt %: %/%',
                v_i, v_claim.work_id, v_claim.attempt_number;
        END IF;
        v_token := v_claim.claim_token;
    END LOOP;

    SELECT * INTO v_result
      FROM system.complete_reputation_processing_work(
          v_work_id,
          v_token,
          'retryable',
          'transient_technical',
          'transient_failure',
          'final transient failure'
      );

    IF v_result.status <> 'dead_letter'
       OR v_result.attempt_count <> 5 THEN
        RAISE EXCEPTION 'Retry exhaustion result mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_work w
         WHERE w.id=v_work_id
           AND w.status='dead_letter'
           AND w.dead_letter_reason_code='retry_budget_exhausted'
           AND w.dead_lettered_at IS NOT NULL
           AND w.claimed_at IS NULL
           AND w.claim_token IS NULL
           AND w.attempt_count=5
    ) THEN
        RAISE EXCEPTION 'Exhausted work row state mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_attempts a
         WHERE a.work_id=v_work_id
           AND a.attempt_number=5
           AND a.outcome='dead_letter'
    ) THEN
        RAISE EXCEPTION 'Exhausted attempt history missing or wrong';
    END IF;

    SELECT max(a.attempt_number) INTO v_i
      FROM reputation.processing_attempts a
     WHERE a.work_id=v_work_id;
    IF v_i > 5 THEN
        RAISE EXCEPTION 'Attempt number exceeded max_attempts';
    END IF;

    SELECT count(*) INTO v_count
      FROM system.claim_reputation_processing_work(1, 'worker-sixth', 300);
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Exhausted work was claimed again';
    END IF;

    SELECT * INTO v_result
      FROM system.enqueue_reputation_stock_order_work(
          'a1000000-0000-4000-8000-000000000003'
      );
    IF v_result.created IS DISTINCT FROM false
       OR v_result.status <> 'dead_letter'
       OR v_result.work_id <> v_work_id THEN
        RAISE EXCEPTION 'Enqueue reopened dead-letter work';
    END IF;
END;
$exhaustion$;

DO $stale_claim$
DECLARE
    v_result record;
    v_work_id uuid;
    v_claim_a record;
    v_claim_b record;
    v_count integer;
BEGIN
    SELECT * INTO v_result
      FROM system.enqueue_reputation_stock_order_work(
          'a1000000-0000-4000-8000-000000000004'
      );
    v_work_id := v_result.work_id;

    SELECT * INTO v_claim_a
      FROM system.claim_reputation_processing_work(1, 'worker-a', 1);
    IF v_claim_a.work_id <> v_work_id OR v_claim_a.attempt_number <> 1 THEN
        RAISE EXCEPTION 'Stale claim first claim mismatch';
    END IF;

    PERFORM pg_sleep(1.1);

    SELECT * INTO v_claim_b
      FROM system.claim_reputation_processing_work(1, 'worker-b', 300);
    IF v_claim_b.work_id <> v_work_id
       OR v_claim_b.attempt_number <> 2
       OR v_claim_b.claim_token = v_claim_a.claim_token THEN
        RAISE EXCEPTION 'Reclaim did not rotate the claim token';
    END IF;

    SELECT count(*) INTO v_count
      FROM reputation.processing_attempts
     WHERE work_id=v_work_id;

    BEGIN
        PERFORM system.complete_reputation_processing_work(
            v_work_id, v_claim_a.claim_token, 'succeeded'
        );
        RAISE EXCEPTION 'Stale claim completion unexpectedly succeeded';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
    END;

    IF (SELECT count(*) FROM reputation.processing_attempts WHERE work_id=v_work_id)
       <> v_count THEN
        RAISE EXCEPTION 'Stale completion appended an attempt row';
    END IF;

    SELECT * INTO v_result
      FROM system.complete_reputation_processing_work(
          v_work_id, v_claim_b.claim_token, 'succeeded'
      );
    IF v_result.status <> 'succeeded' OR v_result.attempt_count <> 2 THEN
        RAISE EXCEPTION 'New claim completion failed';
    END IF;
END;
$stale_claim$;

DO $permanent_failure$
DECLARE
    v_result record;
    v_work_id uuid;
    v_claim record;
BEGIN
    SELECT * INTO v_result
      FROM system.enqueue_reputation_stock_order_work(
          'a1000000-0000-4000-8000-000000000005'
      );
    v_work_id := v_result.work_id;

    SELECT * INTO v_claim
      FROM system.claim_reputation_processing_work(1, 'worker-permanent', 300);
    IF v_claim.work_id <> v_work_id OR v_claim.attempt_number <> 1 THEN
        RAISE EXCEPTION 'Permanent failure claim mismatch';
    END IF;

    SELECT * INTO v_result
      FROM system.complete_reputation_processing_work(
          v_work_id,
          v_claim.claim_token,
          'dead_letter',
          'ineligible_business',
          'missing_buyer_entity',
          'buyer_entity_id is missing'
      );

    IF v_result.status <> 'dead_letter'
       OR v_result.attempt_count <> 1 THEN
        RAISE EXCEPTION 'Permanent failure completion mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_work w
         WHERE w.id=v_work_id
           AND w.status='dead_letter'
           AND w.dead_letter_reason_code='missing_buyer_entity'
           AND w.dead_lettered_at IS NOT NULL
           AND w.claimed_at IS NULL
           AND w.claim_token IS NULL
           AND w.last_error_category='ineligible_business'
           AND w.last_error_code='missing_buyer_entity'
    ) THEN
        RAISE EXCEPTION 'Dead-letter work row state mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_attempts a
         WHERE a.work_id=v_work_id
           AND a.attempt_number=1
           AND a.outcome='dead_letter'
           AND a.error_category='ineligible_business'
           AND a.error_code='missing_buyer_entity'
    ) THEN
        RAISE EXCEPTION 'Dead-letter attempt history missing or wrong';
    END IF;

    SELECT * INTO v_result
      FROM system.enqueue_reputation_stock_order_work(
          'a1000000-0000-4000-8000-000000000005'
      );
    IF v_result.created IS DISTINCT FROM false
       OR v_result.status <> 'dead_letter'
       OR v_result.work_id <> v_work_id THEN
        RAISE EXCEPTION 'Enqueue reopened dead-letter work';
    END IF;
END;
$permanent_failure$;



DO $retryable_exhaustion$
DECLARE
    v_work_id uuid;
    v_claim record;
    v_result record;
    v_now timestamptz := clock_timestamp();
    v_max_attempt integer;
BEGIN
    INSERT INTO reputation.processing_work (
        work_kind, source_system, source_reference, status,
        attempt_count, max_attempts, next_attempt_at,
        last_attempt_at, last_error_category, last_error_code,
        last_error_message, created_at, updated_at
    ) VALUES (
        'stock_order_engagement_ingestion', 'vunio', gen_random_uuid()::text,
        'retryable', 4, 5, v_now,
        v_now, 'transient_technical', 'seed_exhaustion',
        'seed exhaustion fixture', v_now, v_now
    ) RETURNING id INTO v_work_id;

    SELECT * INTO v_claim
      FROM system.claim_reputation_processing_work(1, 'worker-retry-exhaust', 300);
    IF v_claim.work_id <> v_work_id OR v_claim.attempt_number <> 5 THEN
        RAISE EXCEPTION 'Retryable exhaustion claim mismatch';
    END IF;

    SELECT * INTO v_result
      FROM system.complete_reputation_processing_work(
          v_work_id,
          v_claim.claim_token,
          'retryable',
          'transient_technical',
          'retry_exhausted',
          'retry budget exhausted'
      );

    IF v_result.status <> 'dead_letter'
       OR v_result.attempt_count <> 5 THEN
        RAISE EXCEPTION 'Retryable exhaustion did not dead-letter';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM reputation.processing_work w
         WHERE w.id=v_work_id
           AND w.status='dead_letter'
           AND w.dead_letter_reason_code='retry_budget_exhausted'
           AND w.attempt_count=5
    ) THEN
        RAISE EXCEPTION 'Retryable exhaustion final state is wrong';
    END IF;

    SELECT max(a.attempt_number) INTO v_max_attempt
      FROM reputation.processing_attempts a
     WHERE a.work_id=v_work_id;
    IF v_max_attempt <> 5 THEN
        RAISE EXCEPTION 'Retryable exhaustion attempt history is wrong';
    END IF;
END;
$retryable_exhaustion$;

DO $backoff_policy$
DECLARE
    v_attempts integer[] := ARRAY[1, 2, 3, 4, 5, 7];
    v_expected_minutes integer[] := ARRAY[1, 2, 4, 8, 16, 60];
    v_i integer;
    v_work_id uuid;
    v_token uuid;
    v_before timestamptz;
    v_delta_seconds numeric;
    v_result record;
BEGIN
    FOR v_i IN 1..array_length(v_attempts, 1) LOOP
        v_before := clock_timestamp();
        v_token := gen_random_uuid();

        INSERT INTO reputation.processing_work (
            work_kind,
            source_system,
            source_reference,
            status,
            attempt_count,
            max_attempts,
            next_attempt_at,
            claimed_at,
            lease_expires_at,
            claim_token,
            claimed_by,
            last_attempt_at,
            created_at,
            updated_at
        ) VALUES (
            'stock_order_engagement_ingestion',
            'vunio',
            gen_random_uuid()::text,
            'processing',
            v_attempts[v_i],
            10,
            v_before,
            v_before,
            v_before + interval '5 minutes',
            v_token,
            'backoff-fixture',
            v_before,
            v_before,
            v_before
        )
        RETURNING id INTO v_work_id;

        SELECT * INTO v_result
          FROM system.complete_reputation_processing_work(
              v_work_id,
              v_token,
              'retryable',
              'transient_technical',
              'backoff_test',
              'backoff policy test'
          );

        IF v_result.status <> 'retryable'
           OR v_result.attempt_count <> v_attempts[v_i] THEN
            RAISE EXCEPTION 'Backoff fixture completion failed at attempt %',
                v_attempts[v_i];
        END IF;

        SELECT extract(epoch FROM (w.next_attempt_at - v_before))
          INTO v_delta_seconds
          FROM reputation.processing_work w
         WHERE w.id=v_work_id;

        IF v_delta_seconds < (v_expected_minutes[v_i] * 60) - 5
           OR v_delta_seconds > (v_expected_minutes[v_i] * 60) + 5 THEN
            RAISE EXCEPTION
                'Backoff at attempt % was % seconds, expected about % minutes',
                v_attempts[v_i], v_delta_seconds, v_expected_minutes[v_i];
        END IF;

        IF (SELECT w.next_attempt_at FROM reputation.processing_work w WHERE w.id=v_work_id)
           > clock_timestamp() + interval '60 minutes 5 seconds' THEN
            RAISE EXCEPTION 'Backoff exceeded the 60 minute cap';
        END IF;
    END LOOP;
END;
$backoff_policy$;

DO $retryable_lifecycle$
DECLARE
    v_work_id uuid;
    v_claim record;
    v_result record;
    v_now timestamptz := clock_timestamp();
BEGIN
    -- Order 2 already proved pending -> processing -> retryable. This fixture
    -- is due immediately, so it proves retryable -> processing -> succeeded.
    INSERT INTO reputation.processing_work (
        work_kind,
        source_system,
        source_reference,
        status,
        attempt_count,
        max_attempts,
        next_attempt_at,
        last_attempt_at,
        last_error_category,
        last_error_code,
        last_error_message,
        created_at,
        updated_at
    ) VALUES (
        'stock_order_engagement_ingestion',
        'vunio',
        gen_random_uuid()::text,
        'retryable',
        1,
        5,
        v_now,
        v_now,
        'transient_technical',
        'seed_retry',
        'seed retry fixture',
        v_now,
        v_now
    )
    RETURNING id INTO v_work_id;

    SELECT * INTO v_claim
      FROM system.claim_reputation_processing_work(1, 'worker-lifecycle', 300);

    IF v_claim.work_id <> v_work_id
       OR v_claim.attempt_number <> 2
       OR v_claim.claim_token IS NULL THEN
        RAISE EXCEPTION 'Retryable lifecycle claim mismatch';
    END IF;

    SELECT * INTO v_result
      FROM system.complete_reputation_processing_work(
          v_work_id, v_claim.claim_token, 'succeeded'
      );

    IF v_result.status <> 'succeeded'
       OR v_result.attempt_count <> 2 THEN
        RAISE EXCEPTION 'Retryable lifecycle success mismatch';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reputation.processing_attempts a
         WHERE a.work_id=v_work_id
           AND a.attempt_number=2
           AND a.outcome='succeeded'
    ) THEN
        RAISE EXCEPTION 'Retryable lifecycle attempt history mismatch';
    END IF;
END;
$retryable_lifecycle$;

DO $invalid_mutations$
DECLARE
    v_pending uuid;
    v_processing uuid;
    v_succeeded uuid;
    v_dead uuid;
    v_now timestamptz := clock_timestamp();
BEGIN
    INSERT INTO reputation.processing_work (
        work_kind, source_system, source_reference, status,
        attempt_count, max_attempts, next_attempt_at,
        created_at, updated_at
    ) VALUES (
        'stock_order_engagement_ingestion', 'vunio', gen_random_uuid()::text,
        'pending', 0, 5, v_now, v_now, v_now
    ) RETURNING id INTO v_pending;

    BEGIN
        UPDATE reputation.processing_work
           SET status='not_a_status', updated_at=clock_timestamp()
         WHERE id=v_pending;
        RAISE EXCEPTION 'Invalid status mutation succeeded';
    EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
    END;

    BEGIN
        UPDATE reputation.processing_work
           SET status='processing',
               attempt_count=1,
               claimed_at=clock_timestamp(),
               lease_expires_at=clock_timestamp() + interval '5 minutes',
               claimed_by='invalid-worker',
               last_attempt_at=clock_timestamp(),
               updated_at=clock_timestamp()
         WHERE id=v_pending;
        RAISE EXCEPTION 'Processing without claim token succeeded';
    EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
    END;

    BEGIN
        UPDATE reputation.processing_work
           SET status='processing',
               attempt_count=1,
               claimed_at=clock_timestamp(),
               claim_token=gen_random_uuid(),
               claimed_by='invalid-worker',
               last_attempt_at=clock_timestamp(),
               updated_at=clock_timestamp()
         WHERE id=v_pending;
        RAISE EXCEPTION 'Processing without lease succeeded';
    EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
    END;

    INSERT INTO reputation.processing_work (
        work_kind, source_system, source_reference, status,
        attempt_count, max_attempts, next_attempt_at,
        claimed_at, lease_expires_at, claim_token, claimed_by,
        last_attempt_at, created_at, updated_at
    ) VALUES (
        'stock_order_engagement_ingestion', 'vunio', gen_random_uuid()::text,
        'processing', 1, 5, v_now,
        v_now, v_now + interval '5 minutes', gen_random_uuid(), 'fixture',
        v_now, v_now, v_now
    ) RETURNING id INTO v_processing;

    BEGIN
        UPDATE reputation.processing_work
           SET status='succeeded',
               claimed_at=NULL,
               lease_expires_at=NULL,
               claim_token=NULL,
               claimed_by=NULL,
               updated_at=clock_timestamp()
         WHERE id=v_processing;
        RAISE EXCEPTION 'Succeeded without completed_at succeeded';
    EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
    END;

    BEGIN
        UPDATE reputation.processing_work
           SET status='dead_letter',
               claimed_at=NULL,
               lease_expires_at=NULL,
               claim_token=NULL,
               claimed_by=NULL,
               updated_at=clock_timestamp()
         WHERE id=v_processing;
        RAISE EXCEPTION 'Dead letter without terminal fields succeeded';
    EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
    END;

    BEGIN
        UPDATE reputation.processing_work
           SET status='retryable',
               last_error_category='transient_technical',
               last_error_code='invalid_claim_retry',
               updated_at=clock_timestamp()
         WHERE id=v_processing;
        RAISE EXCEPTION 'Retryable with live claim state succeeded';
    EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
    END;

    BEGIN
        UPDATE reputation.processing_work
           SET attempt_count=6,
               claimed_at=clock_timestamp(),
               lease_expires_at=clock_timestamp() + interval '5 minutes',
               claim_token=gen_random_uuid(),
               claimed_by='invalid-worker',
               last_attempt_at=clock_timestamp(),
               updated_at=clock_timestamp()
         WHERE id=v_pending;
        RAISE EXCEPTION 'Attempt count beyond max_attempts succeeded';
    EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
    END;

    INSERT INTO reputation.processing_work (
        work_kind, source_system, source_reference, status,
        attempt_count, max_attempts, next_attempt_at,
        completed_at, created_at, updated_at
    ) VALUES (
        'stock_order_engagement_ingestion', 'vunio', gen_random_uuid()::text,
        'succeeded', 1, 5, v_now, v_now, v_now, v_now
    ) RETURNING id INTO v_succeeded;

    INSERT INTO reputation.processing_work (
        work_kind, source_system, source_reference, status,
        attempt_count, max_attempts, next_attempt_at,
        dead_letter_reason_code, dead_lettered_at, created_at, updated_at
    ) VALUES (
        'stock_order_engagement_ingestion', 'vunio', gen_random_uuid()::text,
        'dead_letter', 1, 5, v_now, 'fixture_terminal', v_now, v_now, v_now
    ) RETURNING id INTO v_dead;

    BEGIN
        UPDATE reputation.processing_work
           SET status='processing',
               attempt_count=attempt_count + 1,
               claimed_at=clock_timestamp(),
               lease_expires_at=clock_timestamp() + interval '5 minutes',
               claim_token=gen_random_uuid(),
               claimed_by='reopen-worker',
               updated_at=clock_timestamp()
         WHERE id=v_succeeded;
        RAISE EXCEPTION 'Succeeded work was reopened';
    EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
    END;

    BEGIN
        UPDATE reputation.processing_work
           SET status='pending',
               attempt_count=0,
               next_attempt_at=clock_timestamp(),
               dead_letter_reason_code=NULL,
               dead_lettered_at=NULL,
               updated_at=clock_timestamp()
         WHERE id=v_dead;
        RAISE EXCEPTION 'Dead-letter work was reopened';
    EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
    END;

    IF NOT EXISTS (SELECT 1 FROM reputation.processing_work WHERE id=v_pending AND status='pending')
       OR NOT EXISTS (SELECT 1 FROM reputation.processing_work WHERE id=v_processing AND status='processing')
       OR NOT EXISTS (SELECT 1 FROM reputation.processing_work WHERE id=v_succeeded AND status='succeeded')
       OR NOT EXISTS (SELECT 1 FROM reputation.processing_work WHERE id=v_dead AND status='dead_letter') THEN
        RAISE EXCEPTION 'Invalid mutation changed controlled work state';
    END IF;
END;
$invalid_mutations$;

DO $immutability$
BEGIN
    BEGIN
        UPDATE reputation.processing_attempts SET error_message = error_message;
        RAISE EXCEPTION 'Attempt UPDATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        DELETE FROM reputation.processing_attempts;
        RAISE EXCEPTION 'Attempt DELETE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        TRUNCATE reputation.processing_attempts;
        RAISE EXCEPTION 'Attempt TRUNCATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$immutability$;

SET LOCAL ROLE service_role;

DO $service_role$
DECLARE
    v_result record;
BEGIN
    SELECT * INTO v_result
      FROM system.enqueue_reputation_stock_order_work(
          'a1000000-0000-4000-8000-000000000001'
      );
    IF v_result.created IS DISTINCT FROM false
       OR v_result.status <> 'succeeded' THEN
        RAISE EXCEPTION 'service_role gateway call failed';
    END IF;

    BEGIN
        PERFORM 1 FROM reputation.processing_work LIMIT 1;
        RAISE EXCEPTION 'service_role read processing_work';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        PERFORM reputation.claim_processing_work(1, 'worker', 300);
        RAISE EXCEPTION 'service_role executed private claim';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        UPDATE reputation.processing_attempts SET error_message = error_message;
        RAISE EXCEPTION 'service_role mutated attempt history';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$service_role$;

RESET ROLE;

SET LOCAL ROLE authenticated;

DO $authenticated$
BEGIN
    BEGIN
        PERFORM system.enqueue_reputation_stock_order_work(
            'a1000000-0000-4000-8000-000000000001'
        );
        RAISE EXCEPTION 'authenticated executed work gateway';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        PERFORM 1 FROM reputation.processing_work LIMIT 1;
        RAISE EXCEPTION 'authenticated read processing_work';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$authenticated$;

RESET ROLE;

ROLLBACK;
