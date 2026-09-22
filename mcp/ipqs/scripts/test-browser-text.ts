import assert from "node:assert/strict";
import { resolveChromePath } from "@codex-mcp/shared-browser-session";
import { chromium } from "playwright-core";

import { readDashboardText } from "../src/dashboard-text.js";
import { collectApiKeyCandidates } from "../src/browser.js";

// Isolated synthetic browser test: every request is fulfilled locally, never sent.
const browser = await chromium.launch({ executablePath: await resolveChromePath(), headless: true });
try {
  const context = await browser.newContext();
  let requests = 0;
  let status = 200;
  let html = `<title>Account</title><a href="/logout">Logout</a>
    <div>Credit Usage</div><div>0 / 0</div><p>Detected as a duplicate free account.</p>
    <input value="private-input-value"><textarea>private-textarea-value</textarea>
    <div hidden>private-hidden-value</div><div style="display:none">private-css-value</div>
    <div style="opacity:0.5">partially visible text</div>
    <p>owner@example.test</p><code>syntheticApiKey1234567890</code>
    <script>globalThis.unwantedScript = true</script>
    <img src="https://example.test/unwanted-image"><iframe src="https://example.test/unwanted-frame"></iframe>`;
  await context.route("**/*", async route => {
    requests += 1;
    assert.equal(route.request().url(), "https://www.ipqualityscore.com/user/dashboard");
    assert.equal(route.request().method(), "GET");
    await route.fulfill({ status, contentType: "text/html; charset=utf-8", body: html });
  });
  const page = await context.newPage();
  const initialHtml = html;
  html = "<title>Synthetic session container</title>";
  await page.goto("https://www.ipqualityscore.com/user/dashboard");
  await page.evaluate(() => {
    const original = globalThis.fetch;
    globalThis.fetch = (input, init) => {
      document.documentElement.dataset.probeCache = init?.cache || "";
      return original.call(globalThis, input, init);
    };
  });
  html = initialHtml;
  const before = requests;
  const result = await readDashboardText(page, "home", 5000);
  await page.waitForTimeout(100);
  assert.equal(requests, before + 1, "inert HTML must not load images or frames");
  assert.equal(result.source, "ipqs-dashboard-fetch");
  assert.equal(await page.evaluate(() => document.documentElement.dataset.probeCache), "no-store");
  assert.equal(result.authenticated, true);
  assert.match(result.text, /0 \/ 0/);
  assert.match(result.text, /duplicate free account/);
  assert.match(result.text, /partially visible text/);
  assert.doesNotMatch(result.text, /private-|owner@example|syntheticApiKey|unwantedScript/);
  assert.equal(await page.title(), "Synthetic session container", "text read must not navigate the page");
  assert.equal(await page.evaluate(() => "unwantedScript" in globalThis), false);

  html = '<form action="/login/submit"><input name="email"><input name="password"></form>';
  const login = await readDashboardText(page, "home", 5000);
  assert.equal(login.httpStatus, 200);
  assert.equal(login.authenticated, false);
  assert.equal(login.loginRequired, true);

  status = 429;
  html = '<a href="/logout">Logout</a>';
  const limited = await readDashboardText(page, "home", 5000);
  assert.equal(limited.httpStatus, 429);
  assert.equal(limited.authenticated, false);

  status = 200;
  html = "x".repeat(1_048_577);
  await assert.rejects(() => readDashboardText(page, "home", 5000), /byte limit/);

  await page.setContent(`<label>Primary API Key<input value="visibleApiKey1234567890"></label>
    <code hidden>hiddenApiKey1234567890</code>
    <div style="display:none"><code>cssHiddenApiKey1234567890</code></div>
    <section inert><div>API Key</div><div>inertApiKey1234567890</div></section>
    <div>API Key</div><div>splitApiKey1234567890</div>`);
  const candidates = await collectApiKeyCandidates(page);
  assert.deepEqual(candidates.map(candidate => candidate.secret).sort(),
    ["visibleApiKey1234567890", "splitApiKey1234567890"].sort());
  console.log(JSON.stringify({ status: "PASS", liveNetworkRequests: 0, realProfileUsed: false,
    cases: ["same-origin-get", "no-navigation", "inert-no-subresources", "redaction", "login-html", "http-error", "body-limit", "visible-key-candidates"] }));
} finally { await browser.close(); }
