import assert from "node:assert/strict";
import test from "node:test";

import {
  IPQS_API_MAX_BODY_BYTES,
  buildLookupUrl,
  getIpqsAccountUsage,
  lookupIpqs,
  validateIpqsApiCredential,
} from "../src/api.js";

const syntheticKey = "syntheticApiKey1234567890";

async function withApiKey(run: () => Promise<void>) {
  const previous = process.env.IPQS_API_KEY;
  process.env.IPQS_API_KEY = syntheticKey;
  try {
    await run();
  } finally {
    if (previous === undefined) delete process.env.IPQS_API_KEY;
    else process.env.IPQS_API_KEY = previous;
  }
}

test("builds bounded header-auth lookup URLs without credentials", () => {
  const url = buildLookupUrl("ip", "192.0.2.1", { strictness: 1, "country[]": ["US", "CA"] });
  assert.equal(url.pathname, "/api/json/ip");
  assert.equal(url.searchParams.get("ip"), "192.0.2.1");
  assert.equal(url.searchParams.get("strictness"), "1");
  assert.deepEqual(url.searchParams.getAll("country[]"), ["US", "CA"]);
  assert.equal(url.href.includes(syntheticKey), false);
  assert.throws(() => buildLookupUrl("ip", "not-an-ip"), /valid IPv4 or IPv6/);
  assert.throws(() => buildLookupUrl("url", "file:///etc/passwd"), /HTTP or HTTPS/);
  assert.throws(() => buildLookupUrl("email", "user@example.test", { key: "forbidden" }), /reserved/);
});

test("uses ipqs-key header, parses JSON once, and never retries", () => withApiKey(async () => {
  let calls = 0;
  const fetchImpl: typeof fetch = async (input, init) => {
    calls += 1;
    const url = new URL(String(input));
    if (url.pathname.startsWith("/api/json/account/")) {
      assert.equal(url.pathname.endsWith(`/${syntheticKey}`), true);
      assert.equal(new Headers(init?.headers).get("ipqs-key"), null);
    } else {
      assert.equal(url.href.includes(syntheticKey), false);
      assert.equal(new Headers(init?.headers).get("ipqs-key"), syntheticKey);
    }
    assert.equal(init?.method, "GET");
    assert.equal(init?.redirect, "error");
    return Response.json({ success: true, fraud_score: 7, api_key: syntheticKey });
  };
  const result = await lookupIpqs("email", "user@example.test", { timeout: 5 }, 1000, fetchImpl);
  assert.equal(calls, 1);
  assert.equal(result.ok, true);
  assert.equal((result.data as any).api_key, "[redacted]");
  assert.equal(JSON.stringify(result).includes(syntheticKey), false);

  const usage = await getIpqsAccountUsage(1000, fetchImpl);
  assert.equal(usage.endpoint, "account");
  assert.equal(JSON.stringify(usage).includes(syntheticKey), false);
  assert.equal(calls, 2);
}));

test("credential import validates through the account endpoint and rejects misleading error bodies", async () => {
  let calls = 0;
  const accepted = await validateIpqsApiCredential(syntheticKey, 1000, async (input, init) => {
    calls += 1;
    const url = new URL(String(input));
    assert.equal(url.pathname.endsWith(`/${syntheticKey}`), true);
    assert.equal(new Headers(init?.headers).get("ipqs-key"), null);
    return Response.json({ success: false, message: "You have insufficient credits to make this query." });
  });
  assert.deepEqual(accepted, { valid: true, status: "accepted-without-credits" });
  assert.equal(calls, 1);
  assert.deepEqual(await validateIpqsApiCredential(syntheticKey, 1000,
    async () => Response.json({ success: true, credits: 0, usage: 0 })),
  { valid: true, status: "accepted-without-credits" });
  assert.deepEqual(await validateIpqsApiCredential(syntheticKey, 1000,
    async () => Response.json({ success: false, message: "Invalid or unauthorized key." })),
  { valid: false, status: "invalid-or-unauthorized" });
  for (const status of [401, 403, 429, 503]) {
    for (const data of [{ success: true, credits: 1000 }, { success: false, message: "insufficient credits" }]) {
      const result = await validateIpqsApiCredential(syntheticKey, 1000, async () => Response.json(data, { status }));
      assert.equal(result.valid, false);
    }
  }
});

test("rejects oversized and non-JSON responses without a retry", () => withApiKey(async () => {
  let calls = 0;
  await assert.rejects(
    () => lookupIpqs("ip", "192.0.2.1", {}, 1000, async () => {
      calls += 1;
      return new Response("not json", { status: 200, headers: { "content-type": "text/html" } });
    }),
    /non-JSON/,
  );
  assert.equal(calls, 1);
  await assert.rejects(
    () => lookupIpqs("ip", "192.0.2.1", {}, 1000, async () => new Response(new ReadableStream({
      start(controller) {
        controller.enqueue(Buffer.alloc(IPQS_API_MAX_BODY_BYTES + 1));
      },
    }), { headers: { "content-type": "application/json" } })),
    /body limit/,
  );
}));
