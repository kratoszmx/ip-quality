import assert from "node:assert/strict";
import { registerHooks } from "node:module";
import test from "node:test";
import { request, type APIRequestContext } from "playwright-core";

type Cookie = { name: string; value: string; domain: string; path: string; expires: number; httpOnly: boolean; secure: boolean; sameSite: string };
const fixture = globalThis as typeof globalThis & { __ipqsSharedCookies?: { read(urls: string[]): Promise<Cookie[]>; write(cookies: Cookie[]): Promise<number> } };

// Test the public default read against a transport double and a synthetic shared
// profile. No real profile, credentials, Chrome process or external requests are used.
test("dashboard reads with the shared profile's cookies preserve transport, authentication and privacy boundaries", async t => {
  const previousProxy = process.env.IPQS_PROXY_SERVER;
  process.env.IPQS_PROXY_SERVER = "http://127.0.0.1:17897";
  const session: Cookie = { name: "session", value: "synthetic", domain: ".ipqualityscore.com", path: "/", expires: -1, httpOnly: true, secure: true, sameSite: "Lax" };
  const cookieReads: string[][] = [], cookieWrites: Cookie[][] = [];
  let jar: Cookie[] = [session];
  fixture.__ipqsSharedCookies = {
    async read(urls) { cookieReads.push(urls); return [session]; },
    async write(cookies) { cookieWrites.push(cookies); return cookies.length; },
  };
  const hooks = registerHooks({ resolve(specifier, context, next) {
    if (specifier !== "@myutils/web-text/shared-chrome") return next(specifier, context);
    const original = next(specifier, context);
    const source = `export * from ${JSON.stringify(original.url)};
      export const readSharedChromeCookies = urls => globalThis.__ipqsSharedCookies.read(urls);
      export const writeSharedChromeCookies = cookies => globalThis.__ipqsSharedCookies.write(cookies);`;
    return { url: `data:text/javascript,${encodeURIComponent(source)}`, shortCircuit: true };
  } });
  let status = 200, contentType = "text/html; charset=utf-8", contentLength: string | undefined;
  let body = Buffer.from('<title>Account</title><a href="/logout">Logout</a>');
  let requests = 0, responsesClosed = 0, contextsClosed = 0, bodyReads = 0;
  let transportFailure = false, cleanupFailure = false;
  let expectedPath = "/user/dashboard";
  t.mock.method(request, "newContext", async (options: Record<string, any>) => {
    assert.deepEqual(options.storageState, { cookies: [session], origins: [] });
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
      async storageState() { return { cookies: jar, origins: [] }; },
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
    await t.test("cookies the site refreshed or removed go back to the shared profile", async () => {
      body = Buffer.from('<a href="/logout">Logout</a>');
      const refreshed = { ...session, value: "rotated", expires: 1_900_000_000 };
      const visitor = { ...session, name: "visitor", value: "new", domain: "www.ipqualityscore.com" };
      jar = [refreshed, visitor];
      assert.equal((await readDashboard("home")).authenticated, true);
      assert.deepEqual(cookieWrites.at(-1), [refreshed, visitor]);
      jar = [];
      await readDashboard("home");
      assert.deepEqual(cookieWrites.at(-1), [{ ...session, expires: 1 }]);
      jar = [session];
    });
    assert.ok(cookieReads.every(urls => urls.length === 1 && urls[0].startsWith("https://www.ipqualityscore.com/user/")));
    assert.equal(cookieWrites.length, 2, "an unchanged cookie jar writes nothing back");
    assert.equal(contextsClosed, requests);
  } finally {
    hooks.deregister(); delete fixture.__ipqsSharedCookies;
    if (previousProxy === undefined) delete process.env.IPQS_PROXY_SERVER;
    else process.env.IPQS_PROXY_SERVER = previousProxy;
  }
});
