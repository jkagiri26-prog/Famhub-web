# Referral Finance Scheduler

Cloudflare Worker scheduler for the existing Supabase Edge Function:

```text
referral-finance-worker
```

The Worker is scheduled-only. It has no public `fetch()` handler, no route, and no HTTP processing endpoint.

## Purpose

Invoke the staging Supabase referral-finance worker every five minutes when the Cron Trigger is enabled.

The Supabase worker remains responsible for authentication, activation-gate enforcement, event selection, idempotency, retries, and dead-letter handling.

## Architecture

```text
Cloudflare Cron Trigger
  -> referral-finance-scheduler-staging
       -> POST Supabase Edge Function
          header: x-worker-secret
          body: {"limit":20}
       -> validate HTTP 200 and worker response contract
       -> write sanitized structured logs
```

The Worker:

- Uses only a `scheduled()` handler.
- Has no `fetch()` handler.
- Has no public route.
- Has no Durable Object.
- Does not access PostgreSQL directly.
- Does not use pg_cron or pg_net.
- Does not retry inside the same invocation.

## Required configuration

Non-secret variable:

```text
SUPABASE_FUNCTION_URL
```

Required Cloudflare Worker secret:

```text
REFERRAL_WORKER_SECRET
```

The secret must be configured through the Cloudflare Worker secrets mechanism. It must never be placed in source code, `wrangler.toml`, this README, tests, logs, GitHub, or any committed file.

## Request behavior

```text
POST <SUPABASE_FUNCTION_URL>
Content-Type: application/json
x-worker-secret: <Cloudflare Worker secret>
body: {"limit":20}
```

Timeout: 60 seconds.

Accepted response: HTTP 200 with valid JSON matching:

```json
{
  "ok": true,
  "run_id": "optional-string",
  "gate_enabled": false,
  "selected_count": 0,
  "processed_count": 0,
  "failed_count": 0
}
```

Validation requirements:

- `ok === true`
- `gate_enabled` is boolean
- all three counts are non-negative integers

HTTP 401, HTTP 500, timeouts, network failures, malformed JSON, and contract failures are logged with sanitized fields only. No immediate retry is performed; the next scheduled invocation is the retry.

## Local testing

From this directory:

```sh
deno check src/index.ts test/scheduler.test.ts
deno test test/scheduler.test.ts
```

The tests use a mocked `fetch()` and a fake non-production secret. They never contact Supabase and never require a real secret.

If Wrangler is installed, local scheduled-handler testing can be done with:

```sh
npx wrangler dev --test-scheduled
```

Do not commit local secret files such as `.dev.vars` or `.env`.

## Staging deployment

The initial configuration intentionally keeps the Cron Trigger disabled:

```toml
[triggers]
crons = []
```

Deployment is not authorized by this repository task. When separately approved:

1. Verify the target Cloudflare account and Worker name.
2. Configure the staging-only secret:
   ```sh
   npx wrangler secret put REFERRAL_WORKER_SECRET
   ```
3. Deploy the Worker with crons still disabled.
4. Verify the Worker exists and has no public route or fetch handler.
5. Enable the staging trigger only after separate approval:
   ```toml
   [triggers]
   crons = ["*/5 * * * *"]
   ```
6. Deploy and monitor Cron Events and Workers Logs.

Production must use a separate Worker, separate URL, and a separate production-only secret. Never reuse the staging secret in production.

## Enable or disable the Cron Trigger

Disable:

```toml
[triggers]
crons = []
```

Deploy again, or delete the Cron Trigger in the Cloudflare Dashboard under the Worker's Triggers settings.

Enable:

```toml
[triggers]
crons = ["*/5 * * * *"]
```

Deploy again after separate approval.

Disabling the trigger stops new scheduled invocations. It does not delete the Worker or affect Supabase.

## Security rules

- Never commit or log `REFERRAL_WORKER_SECRET`.
- Never log request headers, authorization credentials, full request bodies, or full response bodies.
- Do not expose a public Worker endpoint for scheduler processing.
- Keep staging and production secrets independent.
- Keep the Supabase activation gate as the final processing control.
- Do not add direct database access, pg_cron, or pg_net to this Worker.
