# Reputation Processing Scheduler

Cloudflare scheduled-only Worker for the existing Supabase Edge Function:

```text
reputation-processing-worker
```

The Worker has no public `fetch()` handler, no public route, and no HTTP processing endpoint.

## Purpose

Invoke the Reputation processing worker on a schedule. The Edge Function remains responsible for authentication, claiming bounded work, invoking Phase 2C-1 ingestion, completing Phase 2C-2 work, retry classification, and lease recovery.

## Architecture

```text
Cloudflare Cron Trigger
  -> reputation-processing-scheduler
       -> POST Reputation Edge Function
          header: x-worker-secret
          body: {"limit":5}
       -> validate HTTP 200 and worker response contract
       -> write sanitized structured logs
```

The Worker:

- Uses only a `scheduled()` handler.
- Has no `fetch()` handler or public route.
- Does not access PostgreSQL directly.
- Does not use a Supabase service-role key.
- Does not use pg_cron or pg_net.
- Does not retry inside the same invocation.

## Required configuration

Non-secret variable:

```text
REPUTATION_FUNCTION_URL
```

Required Cloudflare Worker secret:

```text
REPUTATION_WORKER_SECRET
```

The secret must be configured through the Cloudflare Worker secrets mechanism. It must never be placed in source code, `wrangler.toml`, this README, tests, logs, GitHub, or any committed file.

The function URL is intentionally not committed. Supply it at deployment time with `--var` or the Cloudflare dashboard.

## Request behavior

```text
POST <REPUTATION_FUNCTION_URL>
Content-Type: application/json
x-worker-secret: <Cloudflare Worker secret>
body: {"limit":5}
```

Timeout: 60 seconds.

Accepted response: HTTP 200 with valid JSON matching:

```json
{
  "ok": true,
  "run_id": "string",
  "worker_id": "string",
  "claimed": 0,
  "succeeded": 0,
  "retryable": 0,
  "dead_lettered": 0,
  "failed": 0,
  "skipped": 0,
  "duration_ms": 0
}
```

HTTP 400, 401, 405, 500, timeouts, network failures, malformed JSON, and contract failures are logged with sanitized fields only. No immediate retry is performed; the next scheduled invocation is the recovery path.

## Local testing

From this directory:

```sh
deno check src/index.ts test/scheduler.test.ts test/configs.test.ts
deno test --allow-read test/scheduler.test.ts test/configs.test.ts
```

The tests use a mocked `fetch()` and a fake non-production secret. They never contact Supabase and never require a real secret.

Do not commit local secret files such as `.dev.vars` or `.env`.

## Staging deployment

The staging configuration intentionally keeps the Cron Trigger disabled:

```toml
[triggers]
crons = []
```

Deployment is not authorized by this repository task. When separately approved:

1. Verify the target Cloudflare account and Worker name.
2. Configure the staging-only secret:
   ```sh
   npx wrangler secret put REPUTATION_WORKER_SECRET
   ```
3. Deploy with the project-specific function URL supplied at deploy time:
   ```sh
   npx wrangler deploy \
     --var REPUTATION_FUNCTION_URL:"https://<project-ref>.supabase.co/functions/v1/reputation-processing-worker"
   ```
4. Verify the Worker exists and has no public route or fetch handler.
5. Enable the staging trigger only after separate approval:
   ```toml
   [triggers]
   crons = ["*/5 * * * *"]
   ```
6. Deploy and monitor Cron Events and Workers Logs.

## Production deployment

Production must use a separate Worker, separate function URL, and a separate production-only secret. Never reuse the staging secret in production.

The production configuration is isolated in:

```text
wrangler.production.toml
```

Deploy only after separate approval:

```sh
npx wrangler secret put REPUTATION_WORKER_SECRET --config wrangler.production.toml
npx wrangler deploy --config wrangler.production.toml \
  --var REPUTATION_FUNCTION_URL:"https://<project-ref>.supabase.co/functions/v1/reputation-processing-worker"
```

The secret is supplied only through Cloudflare Worker secrets and must never be added to either TOML file.

## Security rules

- Never commit or log `REPUTATION_WORKER_SECRET`.
- Never log request headers, authorization credentials, claim tokens, full request bodies, or full response bodies.
- Do not expose a public Worker endpoint.
- Keep staging and production secrets independent.
- Keep the Reputation claim/lease ledger as the only concurrency and recovery mechanism.
- Do not add direct database access, pg_cron, or pg_net to this Worker.
