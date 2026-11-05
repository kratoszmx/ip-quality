import assert from "node:assert/strict";
import { mkdtemp, realpath, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { request, type APIRequestContext } from "playwright-core";

// Test the public default read against a transport double, with synthetic state.
// No real profile, credentials, browser process or external requests are used.
test("saved HTTP dashboard reads preserve transport, authentication and privacy boundaries", async t => {
  const directory = await mkdtemp(path.join(await realpath(tmpdir()), "ipqs-http-text-"));
  const previousProfile = process.env.IPQS_BROWSER_PROFILE_DIR;
  const previousProxy = process.env.IPQS_PROXY_SERVER;
  process.env.IPQS_BROWSER_PROFILE_DIR = directory;
  process.env.IPQS_PROXY_SERVER = "http://127.0.0.1:17897";
  const stateFile = path.join(directory, "http-session.json");
  const state = {
    cookies: [
      { name: "session", value: "synthetic", domain: ".ipqualityscore.com", path: "/", expires: -1, httpOnly: true, secure: true, sameSite: "Lax" },
      { name: "foreign", value: "excluded", domain: "foreign.invalid", path: "/", expires: -1, httpOnly: true, secure: true, sameSite: "Lax" },
    ],
    origins: [{ origin: "https://foreign.invalid", localStorage: [{ name: "private", value: "excluded" }] }],
  };
  await writeFile(stateFile, JSON.stringify(state), { mode: 0o600 });
  let status = 200, contentType = "text/html; charset=utf-8", contentLength: string | undefined;
  let body = Buffer.from('<title>Account</title><a href="/logout">Logout</a>');
  let requests = 0, responsesClosed = 0, contextsClosed = 0, bodyReads = 0;
  let transportFailure = false, cleanupFailure = false;
  let expectedPath = "/user/dashboard";
  const originalState = JSON.stringify(state);
  t.mock.method(request, "newContext", async (options: Record<string, any>) => {
    assert.deepEqual(options.storageState, { cookies: [state.cookies[0]], origins: [] });
    assert.deepEqual(options.proxy, { server: "http://127.0.0.1:17897" });
    return {
      async get(url: string, options: Record<string, any>) {
        requests++;
        assert.equal(url, `https://www.ipqualityscore.com${expectedPath}`);
        assert.equal(options.maxRedirects, 0);
        assert.equal(options.maxRetries, 0);
        assert.equal(options.timeout, 15000);
        assert.equal(options.headers["Cache-Control"], "no-store");
        assert.equal(options.headers.Accept, "text/html");
        if (transportFailure) throw new Error("synthetic transport failure");
        return {
          status: () => status,
          headers: () => ({ "content-type": contentType, ...(contentLength ? { "content-length": contentLength } : {}) }),
          body: async () => { bodyReads++; return Buffer.from(body); },
          url: () => url,
          dispose: async () => { responsesClosed++; },
        };
      },
      async dispose() { contextsClosed++; if (cleanupFailure) throw new Error("synthetic cleanup failure"); },
    } as unknown as APIRequestContext;
  });
  try {
    const { readDashboard } = await import("../src/browser.js");
    const { probeHttpAuth } = await import("../src/http-auth.js");
    await t.test("one default GET extracts inert text without values or subresources", async () => {
      body = Buffer.from(`<title>Account</title><a href="/logout">Logout</a>
        <div>Credit Usage</div><div>0 / 0</div><p>Detected as a duplicate free account.</p>
        <input value="private-input-value"><textarea>private-textarea-value</textarea><select><option>private-select-value</option></select>
        <div hidden>private-hidden-value</div><div style="display:none">private-css-value</div>
        <div aria-hidden="true">private-aria-value</div><section inert>private-inert-value</section>
        <div style="opacity:0.5">partially visible text</div>
        <p>owner@example.test</p><code>syntheticApiKey1234567890</code>
        <div>Emergency Backup Code <code>12345678</code></div>
        <script>globalThis.unwantedScript = true</script><style>private-style</style>
        <img src="https://foreign.invalid/image"><iframe src="https://foreign.invalid/frame"></iframe>`);
      const r = await readDashboard("home", 5000);
      assert.equal(r.source, "ipqs-dashboard-http");
      assert.equal(r.authenticated, true);
      assert.equal(r.title, "Account");
      assert.match(r.text, /0 \/ 0/);
      assert.match(r.text, /duplicate free account/);
      assert.match(r.text, /partially visible text/);
      assert.doesNotMatch(r.text, /private-|owner@example|syntheticApiKey|unwantedScript|12345678|foreign\.invalid/);
      assert.equal(requests, 1);
      assert.equal(responsesClosed, 1);
      assert.equal(contextsClosed, 1);
      assert.deepEqual(r.controls, []);
    });
    await t.test("all named pages and text limit use the same bounded transport", async () => {
      for (const [page, pagePath] of [["settings", "/user/settings"], ["api_keys", "/user/api-keys"]] as const) {
        expectedPath = pagePath;
        const r = await readDashboard(page, 40);
        assert.equal(r.path, pagePath);
        assert.ok(r.text.length <= 40);
      }
      expectedPath = "/user/dashboard";
    });
    await t.test("hidden logout cannot prove authentication; inert login cannot negate it", async () => {
      body = Buffer.from('<p>Loading</p><div style="visibility:hidden"><a href="/logout">Logout</a></div>');
      assert.equal((await readDashboard("home")).authenticated, false);
      body = Buffer.from('<a href="/logout">Logout</a><div inert><form action="/login/submit"></form></div>');
      assert.equal((await readDashboard("home")).authenticated, true);
    });
    await t.test("HTTP 200 login and TOTP pages remain unauthenticated", async () => {
      for (const html of ['<form action="/login/submit"><input name="email"><input name="password"></form>',
        '<a href="/logout">Logout</a><form><input name="2fa"><button>Finish Login</button></form>']) {
        body = Buffer.from(html);
        const r = await readDashboard("home");
        assert.equal(r.authenticated, false);
        assert.ok("loginRequired" in r);
        assert.equal(r.loginRequired, true);
        assert.equal((await probeHttpAuth()).authenticated, false);
      }
    });
    await t.test("redirects and failed HTTP statuses are not retried or read", async () => {
      body = Buffer.from('<a href="/logout">Logout</a>');
      const reads = bodyReads;
      const before = requests;
      for (status of [302, 401, 403, 429, 500]) {
        const r = await readDashboard("home");
        assert.equal(r.authenticated, false);
        assert.ok("httpStatus" in r);
        assert.equal(r.httpStatus, status);
        assert.equal(r.text, "");
      }
      assert.equal(bodyReads, reads);
      assert.equal(requests, before + 5);
      status = 200;
    });
    await t.test("oversized declared and actual bodies fail with response cleanup", async () => {
      const before = responsesClosed;
      contentLength = "1048577";
      await assert.rejects(() => readDashboard("home"), /byte limit/);
      contentLength = undefined;
      body = Buffer.alloc(1048577, 120);
      await assert.rejects(() => readDashboard("home"), /byte limit/);
      assert.equal(responsesClosed, before + 2);
    });
    await t.test("non-HTML, unsupported charset and malformed UTF-8 are rejected", async () => {
      body = Buffer.from('<a href="/logout">Logout</a>');
      contentType = "application/json";
      await assert.rejects(() => readDashboard("home"), /content type/);
      contentType = "text/html; charset=iso-8859-1";
      await assert.rejects(() => readDashboard("home"), /charset/);
      contentType = "text/html; charset=utf-8";
      body = Buffer.from([0xc3, 0x28]);
      await assert.rejects(() => readDashboard("home"), /encoded data/);
    });
    await t.test("transport failures are terminal and still dispose the context", async () => {
      transportFailure = true;
      const before = requests;
      await assert.rejects(() => readDashboard("home"), /transport failure/);
      assert.equal(requests, before + 1);
      assert.equal(contextsClosed, requests);
      transportFailure = false;
    });
    await t.test("cleanup failure cannot become successful account evidence", async () => {
      body = Buffer.from('<a href="/logout">Logout</a>');
      cleanupFailure = true;
      await assert.rejects(() => readDashboard("home"), /cleanup failure/);
      assert.equal((await probeHttpAuth()).stage, "unavailable");
      cleanupFailure = false;
    });
    const { readFile } = await import("node:fs/promises");
    assert.equal(await readFile(stateFile, "utf8"), originalState, "reads never rewrite saved authentication");
    assert.equal(contextsClosed, requests);
  } finally {
    if (previousProfile === undefined) delete process.env.IPQS_BROWSER_PROFILE_DIR;
    else process.env.IPQS_BROWSER_PROFILE_DIR = previousProfile;
    if (previousProxy === undefined) delete process.env.IPQS_PROXY_SERVER;
    else process.env.IPQS_PROXY_SERVER = previousProxy;
    await rm(directory, { recursive: true, force: true });
  }
});
