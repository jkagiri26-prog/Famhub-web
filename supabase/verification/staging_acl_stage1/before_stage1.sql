-- ============================================================================
-- READ-ONLY VERIFICATION PACK
-- Run once BEFORE and once AFTER the approved ACL handoff.
-- No GRANT, REVOKE, ALTER, CREATE, DROP, or data-changing statements.
-- ============================================================================

DO $verify$
DECLARE
    v_count integer;
BEGIN
    IF to_regclass('net.http_request_queue') IS NULL
       OR to_regclass('net._http_response') IS NULL
       OR to_regclass('net.http_request_queue_id_seq') IS NULL
       OR to_regclass('cron.job') IS NULL
       OR to_regclass('cron.job_run_details') IS NULL
       OR to_regclass('cron.jobid_seq') IS NULL
       OR to_regclass('cron.runid_seq') IS NULL THEN
        RAISE EXCEPTION 'Expected pg_net/pg_cron object is missing';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM (VALUES
            ('net.http_post(text,jsonb,jsonb,jsonb,integer)'),
            ('net._urlencode_string(character varying)'),
            ('net._encode_url_with_params_array(text,text[])'),
            ('net.wake()'),
            ('net._await_response(bigint)'),
            ('net._http_collect_response(bigint,boolean)'),
            ('net.check_worker_is_up()'),
            ('net.http_collect_response(bigint,boolean)'),
            ('net.http_delete(text,jsonb,jsonb,integer,jsonb)'),
            ('net.http_get(text,jsonb,jsonb,integer)'),
            ('net.wait_until_running()'),
            ('net.worker_restart()'),
            ('cron.alter_job(bigint,text,text,text,text,boolean)'),
            ('cron.schedule(text,text,text)'),
            ('cron.schedule(text,text)'),
            ('cron.schedule_in_database(text,text,text,text,text,boolean)'),
            ('cron.unschedule(text)'),
            ('cron.unschedule(bigint)')
          ) AS expected(sig)
         WHERE to_regprocedure(expected.sig) IS NULL
    ) THEN
        RAISE EXCEPTION 'Expected pg_net/pg_cron function signature is missing';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_extension
     WHERE (extname='pg_net' AND extversion='0.20.4')
        OR (extname='pg_cron' AND extversion='1.6.4');
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'Expected pg_net 0.20.4 and pg_cron 1.6.4';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
     WHERE n.nspname='net';
    IF v_count = 0 THEN
        RAISE EXCEPTION 'No net functions found';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
     WHERE n.nspname='cron';
    IF v_count = 0 THEN
        RAISE EXCEPTION 'No cron functions found';
    END IF;
END;
$verify$;

-- Context: project ref cannot be read from SQL; operator must verify Dashboard.
SELECT current_database() AS database_name,
       current_user AS executing_role,
       now() AS captured_at;

-- 1. Full ACL snapshot: schema, tables, sequences, functions.
--    grantee = '-' means PUBLIC.
--    acl_source distinguishes explicit ACL from implicit default ACL.
SELECT 'schema' AS object_class, n.nspname AS schema_name,
       NULL::text AS object_name,
       a.grantee::regrole::text AS grantee,
       a.grantor::regrole::text AS grantor,
       a.privilege_type, a.is_grantable,
       CASE WHEN n.nspacl IS NULL THEN 'implicit_default' ELSE 'explicit' END AS acl_source
FROM pg_namespace n
CROSS JOIN LATERAL aclexplode(COALESCE(n.nspacl, acldefault('n', n.nspowner))) a
WHERE n.nspname IN ('net','cron')

UNION ALL

SELECT 'relation' AS object_class, n.nspname AS schema_name,
       c.relname AS object_name,
       a.grantee::regrole::text AS grantee,
       a.grantor::regrole::text AS grantor,
       a.privilege_type, a.is_grantable,
       CASE WHEN c.relacl IS NULL THEN 'implicit_default' ELSE 'explicit' END AS acl_source
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('r', c.relowner))) a
WHERE n.nspname IN ('net','cron') AND c.relkind IN ('r','p','f')

UNION ALL

SELECT 'sequence' AS object_class, n.nspname AS schema_name,
       c.relname AS object_name,
       a.grantee::regrole::text AS grantee,
       a.grantor::regrole::text AS grantor,
       a.privilege_type, a.is_grantable,
       CASE WHEN c.relacl IS NULL THEN 'implicit_default' ELSE 'explicit' END AS acl_source
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('S', c.relowner))) a
WHERE n.nspname IN ('net','cron') AND c.relkind='S'

UNION ALL

SELECT 'function' AS object_class, n.nspname AS schema_name,
       p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' AS object_name,
       a.grantee::regrole::text AS grantee,
       a.grantor::regrole::text AS grantor,
       a.privilege_type, a.is_grantable,
       CASE WHEN p.proacl IS NULL THEN 'implicit_default' ELSE 'explicit' END AS acl_source
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
WHERE n.nspname IN ('net','cron')

ORDER BY object_class, schema_name, object_name, grantee, privilege_type;

-- 2. Every table privilege for every net/cron table and all five roles.
SELECT n.nspname, c.relname, r.role_name, p.priv,
       has_table_privilege(r.role_name, c.oid, p.priv) AS allowed
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
CROSS JOIN (VALUES
  ('anon'),('authenticated'),('service_role'),('postgres'),('supabase_functions_admin')
) r(role_name)
CROSS JOIN (VALUES
  ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')
) p(priv)
WHERE n.nspname IN ('net','cron') AND c.relkind IN ('r','p','f')
ORDER BY n.nspname,c.relname,r.role_name,p.priv;

-- 3. All sequence privileges.
SELECT n.nspname, c.relname, r.role_name, p.priv,
       has_sequence_privilege(r.role_name, c.oid, p.priv) AS allowed
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
CROSS JOIN (VALUES
  ('anon'),('authenticated'),('service_role'),('postgres'),('supabase_functions_admin')
) r(role_name)
CROSS JOIN (VALUES ('USAGE'),('SELECT'),('UPDATE')) p(priv)
WHERE n.nspname IN ('net','cron') AND c.relkind='S'
ORDER BY n.nspname,c.relname,r.role_name,p.priv;

-- 4. EXECUTE for every net/cron function, with exact identity arguments.
SELECT n.nspname, p.proname,
       pg_get_function_identity_arguments(p.oid) AS identity_args,
       r.role_name,
       has_function_privilege(r.role_name, p.oid, 'EXECUTE') AS allowed
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
CROSS JOIN (VALUES
  ('anon'),('authenticated'),('service_role'),('postgres'),('supabase_functions_admin')
) r(role_name)
WHERE n.nspname IN ('net','cron')
ORDER BY n.nspname,p.proname,identity_args,r.role_name;

-- 5. Explicit and implicit PUBLIC ACL entries only.
SELECT 'schema' AS object_class, n.nspname AS schema_name, NULL::text AS object_name,
       a.grantor::regrole::text AS grantor, a.privilege_type, a.is_grantable,
       CASE WHEN n.nspacl IS NULL THEN 'implicit_default' ELSE 'explicit' END AS acl_source
FROM pg_namespace n
CROSS JOIN LATERAL aclexplode(COALESCE(n.nspacl, acldefault('n', n.nspowner))) a
WHERE n.nspname IN ('net','cron') AND a.grantee=0

UNION ALL

SELECT 'relation', n.nspname, c.relname,
       a.grantor::regrole::text, a.privilege_type, a.is_grantable,
       CASE WHEN c.relacl IS NULL THEN 'implicit_default' ELSE 'explicit' END
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('r', c.relowner))) a
WHERE n.nspname IN ('net','cron') AND c.relkind IN ('r','p','f') AND a.grantee=0

UNION ALL

SELECT 'sequence', n.nspname, c.relname,
       a.grantor::regrole::text, a.privilege_type, a.is_grantable,
       CASE WHEN c.relacl IS NULL THEN 'implicit_default' ELSE 'explicit' END
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('S', c.relowner))) a
WHERE n.nspname IN ('net','cron') AND c.relkind='S' AND a.grantee=0

UNION ALL

SELECT 'function', n.nspname,
       p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
       a.grantor::regrole::text, a.privilege_type, a.is_grantable,
       CASE WHEN p.proacl IS NULL THEN 'implicit_default' ELSE 'explicit' END
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
WHERE n.nspname IN ('net','cron') AND a.grantee=0
ORDER BY object_class, schema_name, object_name, privilege_type;

-- 6. Effective schema privileges.
SELECT nspname,
       has_schema_privilege('anon', nspname, 'USAGE') AS anon_usage,
       has_schema_privilege('authenticated', nspname, 'USAGE') AS auth_usage,
       has_schema_privilege('service_role', nspname, 'USAGE') AS service_usage,
       has_schema_privilege('postgres', nspname, 'USAGE') AS postgres_usage,
       has_schema_privilege('supabase_functions_admin', nspname, 'USAGE') AS fn_admin_usage
FROM pg_namespace
WHERE nspname IN ('net','cron')
ORDER BY nspname;

-- 7. Role membership, admin option, inheritance, and relevant attributes.
SELECT r.rolname AS member, g.rolname AS granted_role,
       a.admin_option, r.rolinherit
FROM pg_auth_members a
JOIN pg_roles r ON r.oid=a.member
JOIN pg_roles g ON g.oid=a.roleid
WHERE r.rolname IN ('anon','authenticated','service_role','postgres','supabase_functions_admin')
ORDER BY 1,2;

SELECT rolname, rolcanlogin, rolinherit, rolsuper,
       rolcreaterole, rolcreatedb, rolbypassrls
FROM pg_roles
WHERE rolname IN ('anon','authenticated','service_role','postgres','supabase_functions_admin')
ORDER BY rolname;

-- 8. Cron job count and job details.
SELECT count(*) AS cron_job_count FROM cron.job;
SELECT jobid, jobname, schedule, command, active, username, database
FROM cron.job
ORDER BY jobid;

-- 9. Pending pg_net request count.
SELECT count(*) AS pending_net_request_count
FROM net.http_request_queue;

-- 10. Activation gate.
SELECT foundation_activation_enabled
FROM referrals.program_settings
WHERE id=true;

-- 11. Eight staging business counts.
SELECT
  (SELECT count(*) FROM referrals.referrals) AS referrals,
  (SELECT count(*) FROM referrals.referrals WHERE status='qualified') AS qualified_referrals,
  (SELECT count(*) FROM referrals.rewards WHERE status='eligible') AS eligible_rewards,
  (SELECT count(*) FROM referrals.rewards WHERE status='paid') AS paid_rewards,
  (SELECT count(*) FROM finance.events
    WHERE event_type='finance.subscription.annual.activated') AS activation_events,
  (SELECT count(*) FROM finance.events e
     LEFT JOIN referrals.event_consumptions ec
       ON ec.finance_event_id=e.id
    WHERE e.event_type='finance.subscription.annual.activated'
      AND ec.id IS NULL) AS unconsumed_events,
  (SELECT count(*) FROM referrals.withdrawal_requests) AS withdrawal_requests,
  (SELECT count(*) FROM referrals.review_cases WHERE status='open') AS open_reviews;
