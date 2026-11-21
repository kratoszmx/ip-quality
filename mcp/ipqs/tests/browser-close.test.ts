import assert from "node:assert/strict";
import { registerHooks } from "node:module";
import test from "node:test";

type View = { locale: string; window: string; deadline: number; page?: string };
const fixture = globalThis as typeof globalThis & {
  __ipqsChrome?: { use(runtime: unknown, view: View, use: (session: unknown, page: unknown) => Promise<unknown>): Promise<unknown>; release(): Promise<void> };
};

// Resolve only the shared Chrome modules to synthetic ones. The actual public
// browser entrypoints and their operation queue run unchanged; no Chrome starts.
test("pages are tabs of the shared Chrome and close releases only this server's attachment", async t => {
  const views: View[] = [], runtimes: unknown[] = [];
  let releases = 0, releaseFailure: (() => Promise<void>) | undefined;
  const page = { goto: async () => null, evaluate: async () => false, url: () => "https://www.ipqualityscore.com/login" };
  fixture.__ipqsChrome = {
    async use(runtime, view, use) { runtimes.push(runtime); views.push(view); return use({}, page); },
    async release() { releases++; if (releaseFailure) await releaseFailure(); },
  };
  const modules: Record<string, string> = {
    "@myutils/web-text/dedicated-chrome": `export const withDedicatedChrome = (...args) => globalThis.__ipqsChrome.use(...args);
      export const releaseDedicatedChromePages = () => globalThis.__ipqsChrome.release();`,
    "@myutils/web-text/shared-chrome": `export const sharedChromeRuntime = ({ chromium }) => ({ fixture: "shared-runtime", chromium });
      export const sharedChromeProfileDir = () => "/synthetic/shared-profile";
      export const sharedChromeCdpPort = () => 19551;
      export const readSharedChromeCookies = async () => { throw Error("unexpected cookie read"); };
      export const writeSharedChromeCookies = async () => { throw Error("unexpected cookie write"); };`,
  };
  const hooks = registerHooks({ resolve(specifier, context, next) {
    return specifier in modules
      ? { url: `data:text/javascript,${encodeURIComponent(modules[specifier]!)}`, shortCircuit: true }
      : next(specifier, context);
  } });
  try {
    const { closeBrowser, startInteractiveLogin, defaultStateSummary } = await import("../src/browser.js");
    assert.equal(defaultStateSummary().profileDir, "/synthetic/shared-profile");
    assert.equal((await startInteractiveLogin()).opened, true);
    assert.equal(views.at(-1)?.window, "hidden");
    assert.equal(views.at(-1)?.page, "retain");
    assert.equal((runtimes.at(-1) as { fixture: string }).fixture, "shared-runtime");
    assert.equal((await startInteractiveLogin(true)).backend, "shared-chrome-window");
    assert.equal(views.at(-1)?.window, "shown");

    assert.deepEqual(await closeBrowser(), { released: true });
    assert.equal(releases, 1);

    await t.test("a failed release reports uncertainty without its error text", async () => {
      releaseFailure = async () => { throw Error("private cookie=fixture-secret"); };
      const result = await closeBrowser();
      assert.deepEqual(result, { released: false, cleanup: { status: "unverified", code: "BROWSER_CLEANUP_UNVERIFIED" } });
      assert(!JSON.stringify(result).includes("fixture-secret"));
    });
    await t.test("a hanging release is bounded and a late rejection is not reported as success", async () => {
      const started = Promise.withResolvers<void>(), pending = Promise.withResolvers<void>();
      releaseFailure = async () => { started.resolve(); await pending.promise; };
      t.mock.timers.enable({ apis: ["setTimeout"] });
      const closing = closeBrowser();
      await started.promise;
      t.mock.timers.tick(10000);
      assert.deepEqual(await closing, { released: false, cleanup: { status: "unverified", code: "BROWSER_CLEANUP_UNVERIFIED" } });
      pending.reject(Error("late private cleanup"));
      t.mock.timers.reset();
      releaseFailure = undefined;
      assert.deepEqual(await closeBrowser(), { released: true });
    });
  } finally {
    hooks.deregister(); delete fixture.__ipqsChrome;
  }
});
