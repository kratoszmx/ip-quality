import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
import test from 'node:test';

// Exercise the public page entries with the shared Chrome modules resolved to
// synthetic ones. No profile, Chrome process, account data or network is used.
test('account pages are tabs of the shared Chrome: own reads, kept flows and released attachments', async () => {
  const views = [], visited = [];
  let releases = 0, failNavigation = false;
  const page = {
    goto: async url => { visited.push(url); if (failNavigation) throw Error('synthetic navigation failure'); },
    url: () => visited.at(-1) || 'about:blank',
  };
  globalThis.__providerChrome = {
    async use(runtime, view, use) {
      assert.equal(runtime.fixture, 'shared-runtime');
      views.push(view);
      if (view.page === 'current' && !globalThis.__providerChrome.kept) throw Object.assign(Error('no kept DOM tab'), { code: 'DOM_PAGE_NOT_KEPT' });
      const result = await use({}, page);
      if (view.page === 'retain' && view.window === 'hidden') globalThis.__providerChrome.kept = true;
      return result;
    },
    async release() { releases++; globalThis.__providerChrome.kept = false; },
  };
  const modules = {
    '@myutils/web-text/dedicated-chrome': `export const withDedicatedChrome = (...args) => globalThis.__providerChrome.use(...args);
      export const releaseDedicatedChromePages = () => globalThis.__providerChrome.release();`,
    '@myutils/web-text/shared-chrome': `export const sharedChromeRuntime = () => ({ fixture: 'shared-runtime' });
      export const readSharedChromeCookies = async () => { throw Error('unexpected cookie read'); };
      export const writeSharedChromeCookies = async () => { throw Error('unexpected cookie write'); };
      export const readSharedChromeLocalStorage = async () => { throw Error('unexpected storage read'); };`,
  };
  const hooks = registerHooks({ resolve(specifier, context, next) {
    return Object.hasOwn(modules, specifier)
      ? { url: `data:text/javascript,${encodeURIComponent(modules[specifier])}`, shortCircuit: true }
      : next(specifier, context);
  } });
  try {
    const { readAccount, withSession, closeAccountBrowsers } = await import('../accounts.mjs');
    // The navigation fails before the snapshot, so no private account file is read.
    failNavigation = true;
    await assert.rejects(readAccount('ipapi', 'browser'), /synthetic navigation failure/);
    failNavigation = false;
    assert.deepEqual(visited, ['https://ipapi.is/app/home']);
    assert.deepEqual({ window: views.at(-1).window, page: views.at(-1).page }, { window: 'hidden', page: 'own' });

    // A flow continues on the tab its opening call kept, and only for that provider.
    await assert.rejects(withSession('cloudflare', async () => 'unexpected', { page: 'current' }), /Open the provider page first/);
    assert.equal(views.length, 1);
    await withSession('cloudflare', async tab => tab.goto('https://dash.cloudflare.com/'));
    assert.equal(views.at(-1).page, 'retain');
    assert.equal(await withSession('cloudflare', async () => 'continued', { page: 'current' }), 'continued');
    await assert.rejects(withSession('ipapi', async () => 'unexpected', { page: 'current' }), /Open the provider page first/);
    await withSession('abuseipdb', async () => 'window', { foreground: true });
    assert.equal(views.at(-1).window, 'shown');
    assert.equal(await withSession('cloudflare', async () => 'still kept', { page: 'current' }), 'still kept');

    failNavigation = true;
    await assert.rejects(withSession('ipapi', async tab => tab.goto('https://ipapi.is/app/')), /synthetic navigation failure/);
    await assert.rejects(withSession('cloudflare', async () => 'unexpected', { page: 'current' }), /Open the provider page first/);
    failNavigation = false;

    assert.deepEqual(await closeAccountBrowsers(), { released: true });
    assert.equal(releases, 1);
    await assert.rejects(withSession('cloudflare', async () => 'unexpected', { page: 'current' }), /Open the provider page first/);
  } finally {
    hooks.deregister(); delete globalThis.__providerChrome;
  }
});
