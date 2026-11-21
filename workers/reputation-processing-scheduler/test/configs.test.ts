import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

async function config(name: string): Promise<string> {
  return await Deno.readTextFile(
    new URL(`../${name}`, import.meta.url),
  );
}

Deno.test("staging configuration is cron-disabled and has no hard-coded URL", async () => {
  const source = await config("wrangler.toml");
  assertEquals(
    source.includes('name = "reputation-processing-scheduler-staging"'),
    true,
  );
  assertEquals(source.includes("crons = []"), true);
  assertEquals(source.includes('REPUTATION_FUNCTION_URL = ""'), true);
  assertFalse(source.includes("supabase.co"));
  assertFalse(source.includes("REFERRAL_WORKER_SECRET"));
  assertFalse(source.includes("REPUTATION_WORKER_SECRET"));
});

Deno.test("production configuration runs every five minutes and has no hard-coded URL", async () => {
  const source = await config("wrangler.production.toml");
  assertEquals(
    source.includes('name = "reputation-processing-scheduler-production"'),
    true,
  );
  assertEquals(source.includes('crons = ["*/5 * * * *"]'), true);
  assertEquals(source.includes("workers_dev = false"), true);
  assertEquals(source.includes('REPUTATION_FUNCTION_URL = ""'), true);
  assertFalse(source.includes("supabase.co"));
  assertFalse(source.includes("REFERRAL_WORKER_SECRET"));
  assertFalse(source.includes("REPUTATION_WORKER_SECRET"));
});

Deno.test("staging and production configs cannot cross environments", async () => {
  const staging = await config("wrangler.toml");
  const production = await config("wrangler.production.toml");

  assertFalse(staging.includes("reputation-processing-scheduler-production"));
  assertFalse(production.includes("reputation-processing-scheduler-staging"));
  assertFalse(staging.includes("workers_dev = false"));
  assertFalse(staging.includes('crons = ["*/5 * * * *"]'));
});

Deno.test("scheduler source keeps the scheduled-only, secret-free configuration model", async () => {
  const source = await Deno.readTextFile(
    new URL("../src/index.ts", import.meta.url),
  );

  assertEquals(source.includes("async scheduled("), true);
  assertFalse(source.includes("async fetch("));
  assertFalse(source.includes("fetch(request"));
  assertFalse(source.includes("SUPABASE_SERVICE_ROLE_KEY"));
  assertFalse(source.includes("service_role"));
  assertFalse(source.includes("createClient"));
  assertFalse(source.includes("@supabase"));
  assertFalse(source.includes("retry("));
  assertFalse(source.includes("while ("));
  assertFalse(source.includes("setInterval"));
});
