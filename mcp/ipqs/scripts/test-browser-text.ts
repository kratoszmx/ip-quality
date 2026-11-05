import assert from "node:assert/strict";
import { resolveChromePath } from "@myutils/browser-session";
import { chromium } from "playwright-core";

import { collectApiKeyCandidates } from "../src/browser.js";

// Rendered-control coverage complements the browserless dashboard-text suite.
// No requests can leave this synthetic profile.
const browser = await chromium.launch({ executablePath: await resolveChromePath(), headless: true });
try {
  const context = await browser.newContext({ serviceWorkers: "block" });
  let requests = 0;
  await context.route("**/*", async route => { requests++; await route.abort(); });
  const page = await context.newPage();
  await page.setContent(`<label>Primary API Key<input value="visibleApiKey1234567890"></label>
    <code hidden>hiddenApiKey1234567890</code>
    <div style="display:none"><code>cssHiddenApiKey1234567890</code></div>
    <section inert><div>API Key</div><div>inertApiKey1234567890</div></section>
    <div>API Key</div><div>splitApiKey1234567890</div>`);
  const candidates = await collectApiKeyCandidates(page);
  assert.deepEqual(candidates.map(candidate => candidate.secret).sort(),
    ["visibleApiKey1234567890", "splitApiKey1234567890"].sort());
  assert.equal(requests, 0);
  console.log(JSON.stringify({ status: "PASS", liveNetworkRequests: 0, realProfileUsed: false,
    cases: ["visible-key-candidates", "hidden-key-exclusion", "css-hidden-key-exclusion", "inert-key-exclusion"] }));
} finally { await browser.close(); }
