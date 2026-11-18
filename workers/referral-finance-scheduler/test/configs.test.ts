import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

async function config(name: string): Promise<string> {
  return await Deno.readTextFile(
    new URL(`../${name}`, import.meta.url),
  );
}

const STAGING_REF = "ivcddanirifujxtexmzh";
const PRODUCTION_REF = "erbxiqdfjmqnoeyjupru";
const PRODUCTION_URL =
  `https://${PRODUCTION_REF}.supabase.co/functions/v1/referral-finance-worker`;

Deno.test("staging configuration remains staging-only and cron-disabled", async () => {
  const source = await config("wrangler.toml");
  assertEquals(
    source.includes('name = "referral-finance-scheduler-staging"'),
    true,
  );
  assertEquals(source.includes(`https://${STAGING_REF}.supabase.co`), true);
  assertFalse(source.includes(PRODUCTION_REF));
  assertEquals(source.includes("crons = []"), true);
  assertFalse(source.includes("REFERRAL_WORKER_SECRET"));
});

Deno.test("production configuration targets production and runs every five minutes", async () => {
  const source = await config("wrangler.production.toml");
  assertEquals(
    source.includes('name = "referral-finance-scheduler-production"'),
    true,
  );
  assertEquals(source.includes(PRODUCTION_URL), true);
  assertEquals(source.includes('crons = ["*/5 * * * *"]'), true);
  assertEquals(source.includes("workers_dev = false"), true);
  assertFalse(source.includes(STAGING_REF));
});

Deno.test("production configuration keeps the worker secret out of source", async () => {
  const source = await config("wrangler.production.toml");
  assertFalse(source.includes("REFERRAL_WORKER_SECRET"));
  assertFalse(source.toLowerCase().includes("secret"));
  assertFalse(source.includes("x-worker-secret"));
});

Deno.test("staging and production configs cannot silently cross environments", async () => {
  const staging = await config("wrangler.toml");
  const production = await config("wrangler.production.toml");
  assertFalse(staging.includes(PRODUCTION_REF));
  assertFalse(production.includes(STAGING_REF));
  assertEquals(
    staging.includes("referral-finance-scheduler-production"),
    false,
  );
  assertEquals(
    production.includes("referral-finance-scheduler-staging"),
    false,
  );
});

Deno.test("scheduler source keeps the scheduled-only execution model", async () => {
  const source = await Deno.readTextFile(
    new URL("../src/index.ts", import.meta.url),
  );
  assertEquals(source.includes("async scheduled("), true);
  assertFalse(source.includes("async fetch("));
  assertFalse(source.includes("fetch(request"));
});
