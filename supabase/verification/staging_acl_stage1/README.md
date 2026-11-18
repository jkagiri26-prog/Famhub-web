# Staging ACL Stage 1 Verification

Read-only verification artifacts for the staging-only pg_cron/pg_net ACL hardening operation.

Target project:

```text
ivcddanirifujxtexmzh
```

Do not use these files against production.

## Files

- `before_stage1.sql` — run before the approved ACL handoff and save output as `before.txt`.
- `after_stage1.sql` — byte-for-byte copy of `before_stage1.sql`; run after the approved ACL handoff and save output as `after.txt`.

Both files contain read-only catalog inspection, SELECT statements, and a read-only DO preflight block. The DO block performs only catalog SELECTs and RAISE checks; it makes no data changes.

## How to interpret the output

### PUBLIC ACLs

`grantee = '-'` means the grantee is PUBLIC. `acl_source` distinguishes:

- `explicit` — the ACL was stored directly on the object.
- `implicit_default` — the ACL came from PostgreSQL defaults via `acldefault`.

For pg_net functions, implicit default PUBLIC EXECUTE is expected before remediation. The after snapshot must show that net table/function PUBLIC grants remain unchanged because Stage 1 does not revoke them.

### Direct versus inherited versus effective privileges

- The ACL snapshot shows direct grants only.
- `has_*_privilege` shows effective privilege, including PUBLIC and role inheritance.
- Role membership and `rolinherit` are included to explain inherited effects.
- `anon`, `authenticated`, and `service_role` are NOLOGIN roles, but effective ACL results still matter.
- After Stage 1, API roles should have no effective `net` or `cron` schema USAGE.
- Net table/function `has_*` results may still be true through unchanged PUBLIC object grants. Those grants are not usable without schema USAGE and are explicitly out of scope for Stage 1.
- Cron PUBLIC schema/object access must be removed.

### Net-specific interpretation

Do **not** incorrectly fail Stage 1 merely because net table, sequence or function `has_*_privilege` results remain true for `anon`, `authenticated`, or `service_role` through PUBLIC grants.

Stage 1 requires:

```text
net schema USAGE for anon/auth/service: false
net table/sequence/function PUBLIC grants: unchanged
```

Without `net` schema USAGE, the unchanged object-level PUBLIC grants are not usable through the schema.

## Expected after-stage results

```text
anon/auth/service net schema USAGE: false
anon/auth/service cron schema USAGE: false
anon/auth/service cron table/sequence/function access: false
postgres net schema USAGE: true
supabase_functions_admin net schema USAGE: true
postgres cron administration access: true
PUBLIC net table/sequence/function grants: unchanged
PUBLIC cron schema/object access: removed
cron jobs: 0
pending pg_net requests: 0
activation gate: false
```

Required staging counts:

```text
referrals:             64
qualified referrals:   44
eligible rewards:      31
paid rewards:          13
activation events:     48
unconsumed events:      2
withdrawal requests:   16
open reviews:           1
```

## Operator runbook

1. Confirm project `ivcddanirifujxtexmzh`; do not connect to production.
2. Run the pack with ON_ERROR_STOP enabled and save as `before.txt`:
   ```text
   psql -v ON_ERROR_STOP=1 -f before_stage1.sql
   ```
3. Confirm no query errors and that all expected objects were inspectable.
4. Execute the separately approved ACL handoff as `supabase_admin`.
5. Run the identical pack unchanged with ON_ERROR_STOP enabled and save as `after.txt`:
   ```text
   psql -v ON_ERROR_STOP=1 -f after_stage1.sql
   ```
6. Compare before/after:
   - Net schema usage removed from API roles.
   - Cron access removed from API roles.
   - Postgres retains required cron access.
   - Postgres and `supabase_functions_admin` retain net schema usage.
   - Net PUBLIC table/sequence/function grants unchanged.
   - Cron jobs and net queue remain zero.
   - Gate remains false.
   - All eight counts unchanged.
7. If any query errors, any expected object is missing, or any result is inconclusive, mark the operation **not verified**.

## Safety

- Read-only catalog inspection, SELECT statements, and a read-only DO preflight block. The DO block performs only catalog SELECTs and RAISE checks; it makes no data changes.
- No GRANT, REVOKE, CREATE, ALTER, DROP, or data-changing SQL.
- Do not execute these scripts from this repository review environment.
- Do not modify the separately reviewed ACL handoff.
- No staging or production change is authorized by these files.

## Status

**REVIEWED / NOT EXECUTED.**

No SQL was executed, no connection was made, no request was sent, and no staging or production change was performed.
