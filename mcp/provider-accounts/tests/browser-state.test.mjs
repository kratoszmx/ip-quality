import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtemp, realpath, chmod, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { restoreBrowserState } from '../../common/browser-state.mjs';

test('private login restoration scopes cookies and storage to the requested origin', async () => {
  const dir = await realpath(await mkdtemp(path.join(tmpdir(), 'account-state-')));
  await chmod(dir, 0o700);
  const file = path.join(dir, 'state.json');
  const events = [];
  const context = { addCookies: async value => events.push(value), addInitScript: async (_fn, value) => events.push(value) };
  try {
    assert.equal(await restoreBrowserState(context, file, 'https://account.example'), false);
    await writeFile(file, JSON.stringify({
      cookies: [{ domain: '.account.example', name: 'owned', value: 'private' }, { domain: 'foreign.invalid', name: 'foreign', value: 'private' }],
      origins: [{ origin: 'https://account.example', localStorage: [{ name: 'auth', value: 'private' }] },
        { origin: 'https://foreign.invalid', localStorage: [] }],
    }), { mode: 0o600 });
    assert.equal(await restoreBrowserState(context, file, 'https://account.example'), true);
    assert.equal(events[0].length, 1);
    assert.equal(events[0][0].name, 'owned');
    assert.equal(events[1].origin, 'https://account.example');
    events.length = 0;
    await writeFile(file, '{"cookies":[],"origins":[{"origin":"https://account.example","localStorage":null}]}');
    await assert.rejects(restoreBrowserState(context, file, 'https://account.example'));
    assert.equal(events.length, 0);
    await chmod(file, 0o644);
    await assert.rejects(restoreBrowserState(context, file, 'https://account.example'));
    assert.equal(events.length, 0);
  } finally { await rm(dir, { recursive: true, force: true }); }
});
