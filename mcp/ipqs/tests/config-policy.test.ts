import assert from "node:assert/strict";
import test from "node:test";

import {
  IPQS_ORIGIN,
  ROOT,
  DEFAULT_API_KEY_FILE,
  dashboardUrl,
  getProxyServer,
  isLikelyIpqsApiKey,
  summarizeIpqsUrl,
} from "../src/config.js";
import path from "node:path";

test("reporter and migrated MCP share the project-owned private key", () => {
  assert.equal(DEFAULT_API_KEY_FILE, path.resolve(ROOT, "../../secrets/ipqs"));
});

test("dashboard page URLs are fixed to the trusted IPQS origin", () => {
  assert.equal(dashboardUrl("home"), `${IPQS_ORIGIN}/user/dashboard`);
  assert.equal(dashboardUrl("settings"), `${IPQS_ORIGIN}/user/settings`);
  assert.equal(dashboardUrl("api_keys"), `${IPQS_ORIGIN}/user/api-keys`);
  assert.deepEqual(summarizeIpqsUrl(`${IPQS_ORIGIN}/user/settings?private=value`), {
    trustedOrigin: true,
    path: "/user/settings",
  });
  assert.deepEqual(summarizeIpqsUrl("https://example.com/user/settings"), { trustedOrigin: false });
});

test("API key and proxy policy reject weak or credential-bearing inputs", () => {
  assert.equal(isLikelyIpqsApiKey("syntheticApiKey1234567890"), true);
  assert.equal(isLikelyIpqsApiKey("short123"), false);
  assert.equal(isLikelyIpqsApiKey("123456789012345678901234"), false);

  const previous = process.env.IPQS_PROXY_SERVER;
  try {
    process.env.IPQS_PROXY_SERVER = "http://127.0.0.1:7897";
    assert.equal(getProxyServer(), "http://127.0.0.1:7897");
    process.env.IPQS_PROXY_SERVER = "http://user:secret@127.0.0.1:7897";
    assert.throws(() => getProxyServer(), /credential-free/);
    process.env.IPQS_PROXY_SERVER = "https://127.0.0.1:7897/private";
    assert.throws(() => getProxyServer(), /credential-free/);
  } finally {
    if (previous === undefined) delete process.env.IPQS_PROXY_SERVER;
    else process.env.IPQS_PROXY_SERVER = previous;
  }
});
