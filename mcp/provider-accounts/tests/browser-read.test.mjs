import assert from 'node:assert/strict';
import { mkdtemp, readFile, realpath, rm, writeFile } from 'node:fs/promises';
import { registerHooks } from 'node:module';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

// Exercise the public read entry, real private-state reader and cleanup. Only
// the state-file location and browser boundary are synthetic; no account data,
// Chrome or external network is used.
test('isolated account reads preserve explicit routing and saved state on failure', async () => {
  const directory = await realpath(await mkdtemp(path.join(tmpdir(), 'provider-browser-read-')));
  const stateFile = path.join(directory, 'saved.json');
  const state = JSON.stringify({ cookies: [
    { name: 'fixture', value: 'synthetic', domain: 'ipapi.is', path: '/' },
    { name: 'foreign', value: 'synthetic', domain: 'foreign.invalid', path: '/' },
  ], origins: [] });
  await writeFile(stateFile, state, { mode: 0o600 });
  const previous = Object.fromEntries(['PROVIDER_ACCOUNTS_PROXY', 'HTTPS_PROXY', 'https_proxy'].map(key => [key, process.env[key]]));
  const calls = [];
  let closed = 0, failStartup = false;
  globalThis.__providerReadFixture = { stateFile, async open(runtime, policy) {
    calls.push(runtime);
    assert.deepEqual(policy.storageState.cookies.map(cookie => cookie.name), ['fixture']);
    assert.equal(policy.allowNavigation('https://ipapi.is/app/home'), true);
    assert.equal(policy.allowNavigation('https://foreign.invalid/app/home'), false);
    if (failStartup) throw Error('synthetic startup failure');
    return { page: { goto: async () => { throw Error('synthetic navigation failure'); } },
      close: async () => { closed++; } };
  } };
  const accountsUrl = new URL('../accounts.mjs', import.meta.url).href;
  const hooks = registerHooks({ resolve(specifier, context, next) {
    if (specifier === '@myutils/web-text/browser-sessions') {
      return { url: 'data:text/javascript,export const openIsolatedAccountRead = (...args) => globalThis.__providerReadFixture.open(...args);', shortCircuit: true };
    }
    if (context.parentURL === accountsUrl && specifier === './http-account.mjs') {
      const original = next(specifier, context);
      const source = `export * from ${JSON.stringify(original.url)}; export const httpStatePath = () => globalThis.__providerReadFixture.stateFile;`;
      return { url: `data:text/javascript,${encodeURIComponent(source)}`, shortCircuit: true };
    }
    return next(specifier, context);
  } });
  try {
    const { readAccount } = await import('../accounts.mjs');
    for (const [explicit, upper, lower, expected] of [
      ['DIRECT', 'http://127.0.0.1:17897', undefined, undefined],
      [undefined, undefined, undefined, undefined],
      ['http://127.0.0.1:17898', 'http://127.0.0.1:17897', undefined, 'http://127.0.0.1:17898'],
      [undefined, 'http://127.0.0.1:17897', undefined, 'http://127.0.0.1:17897'],
      [undefined, undefined, 'http://127.0.0.1:17899', 'http://127.0.0.1:17899'],
    ]) {
      for (const [key, value] of Object.entries({ PROVIDER_ACCOUNTS_PROXY: explicit, HTTPS_PROXY: upper, https_proxy: lower })) {
        if (value === undefined) delete process.env[key]; else process.env[key] = value;
      }
      const before = calls.length;
      await assert.rejects(readAccount('ipapi', 'browser'), /synthetic navigation failure/);
      assert.equal(calls.length, before + 1);
      assert.equal(calls.at(-1).proxyServer, expected);
      assert.equal(closed, calls.length);
      assert.equal(await readFile(stateFile, 'utf8'), state);
    }
    const before = calls.length;
    process.env.PROVIDER_ACCOUNTS_PROXY = 'not-a-proxy';
    await assert.rejects(readAccount('ipapi', 'browser'));
    assert.equal(calls.length, before);
    process.env.PROVIDER_ACCOUNTS_PROXY = 'DIRECT';
    failStartup = true;
    await assert.rejects(readAccount('ipapi', 'browser'), /synthetic startup failure/);
    assert.equal(calls.length, before + 1);
    assert.equal(await readFile(stateFile, 'utf8'), state);
    await rm(stateFile);
    await assert.rejects(readAccount('ipapi', 'browser'), /No saved account session/);
    assert.equal(calls.length, before + 1);
  } finally {
    hooks.deregister(); delete globalThis.__providerReadFixture;
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
    await rm(directory, { recursive: true, force: true });
  }
});
