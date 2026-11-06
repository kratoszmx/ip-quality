import assert from "node:assert/strict";
import { mkdtemp, realpath, rm } from "node:fs/promises";
import { registerHooks } from "node:module";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

// Resolve only the native launcher to synthetic sessions. The actual public
// browser entrypoints, shared coordinator and operation queue run unchanged.
test("explicit browser close reports uncertainty and retains the same handle without claiming closure", async t => {
  const directory = await realpath(await mkdtemp(path.join(tmpdir(), "ipqs-close-")));
  const previousProfile = process.env.IPQS_BROWSER_PROFILE_DIR;
  const previousAttach = process.env.PW_CHROMIUM_ATTACH_TO_OTHER;
  process.env.IPQS_BROWSER_PROFILE_DIR = directory;
  let closeCalls = 0, launches = 0, failClose = true, connected = true;
  const session = {
    mode: "hidden", context: {},
    page: { isClosed: () => !connected, goto: async () => {}, url: () => "https://www.ipqualityscore.com/login" },
    browser: { isConnected: () => connected },
    close: async () => { closeCalls++; if (failClose) throw Error("private cookie=fixture-secret"); connected = false; },
  };
  const fixtureGlobal = globalThis as typeof globalThis & { __ipqsCloseFixture?: () => Promise<typeof session> };
  fixtureGlobal.__ipqsCloseFixture = async () => { launches++; return session; };
  const hooks = registerHooks({ resolve(specifier, context, next) {
    if (specifier === "@myutils/browser-session/chrome") {
      return { url: "data:text/javascript,export const launchChromeSession = (...args) => globalThis.__ipqsCloseFixture(...args);", shortCircuit: true };
    }
    return next(specifier, context);
  } });
  try {
    const { closeBrowser, startInteractiveLogin } = await import("../src/browser.js");
    assert.deepEqual(await closeBrowser(), { closed: false, browserOpen: false });
    assert.equal(launches, 0);
    assert.equal((await startInteractiveLogin()).opened, true);
    const result = await closeBrowser();
    assert.deepEqual(result, { closed: false, browserOpen: null,
      cleanup: { status: "unverified", code: "BROWSER_CLEANUP_UNVERIFIED" } });
    assert(!JSON.stringify(result).includes("fixture-secret"));
    assert.equal(closeCalls, 1); assert.equal(launches, 1);
    failClose = false;
    assert.deepEqual(await closeBrowser(), { closed: true, browserOpen: false });
    assert.equal(closeCalls, 2); assert.equal(launches, 1);
    assert.deepEqual(await closeBrowser(), { closed: false, browserOpen: false });
    assert.equal(closeCalls, 2);

    await t.test("a hanging close is bounded and a late rejection does not lose the retryable session", async () => {
      connected = true;
      await startInteractiveLogin();
      const originalClose = session.close;
      const started = Promise.withResolvers<void>(), pending = Promise.withResolvers<void>();
      session.close = async () => { closeCalls++; started.resolve(); await pending.promise; };
      t.mock.timers.enable({ apis: ["setTimeout"] });
      const closing = closeBrowser();
      await started.promise;
      t.mock.timers.tick(10000);
      assert.deepEqual(await closing, { closed: false, browserOpen: null,
        cleanup: { status: "unverified", code: "BROWSER_CLEANUP_UNVERIFIED" } });
      pending.reject(Error("late private cleanup"));
      t.mock.timers.reset();
      session.close = originalClose;
      assert.deepEqual(await closeBrowser(), { closed: true, browserOpen: false });
      assert.equal(launches, 2);
    });
    await t.test("a memoized rejected native close remains unverified on subsequent calls", async () => {
      connected = true;
      await startInteractiveLogin();
      const rejected = Promise.reject(Error("memoized private cleanup failure"));
      session.close = () => rejected;
      for (let attempt = 0; attempt < 2; attempt++) {
        assert.deepEqual(await closeBrowser(), { closed: false, browserOpen: null,
          cleanup: { status: "unverified", code: "BROWSER_CLEANUP_UNVERIFIED" } });
      }
      assert.equal(launches, 3);
    });
  } finally {
    hooks.deregister(); delete fixtureGlobal.__ipqsCloseFixture;
    if (previousProfile === undefined) delete process.env.IPQS_BROWSER_PROFILE_DIR;
    else process.env.IPQS_BROWSER_PROFILE_DIR = previousProfile;
    if (previousAttach === undefined) delete process.env.PW_CHROMIUM_ATTACH_TO_OTHER;
    else process.env.PW_CHROMIUM_ATTACH_TO_OTHER = previousAttach;
    await rm(directory, { recursive: true, force: true });
  }
});
