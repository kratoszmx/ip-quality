import assert from 'node:assert/strict';
import test from 'node:test';
import { changedCookies, withSharedCookies } from '../../common/shared-cookies.mjs';

const cookie = (name, value, domain = '.account.example', expires = -1) =>
  ({ name, value, domain, path: '/', expires, httpOnly: true, secure: true, sameSite: 'Lax' });

test('only the site cookies a response set, changed or removed go back to the shared profile', () => {
  const kept = cookie('kept', 'same'), rotated = cookie('session', 'old'), removed = cookie('removed', 'gone');
  const after = [kept, cookie('session', 'new'), cookie('fresh', 'value', 'www.account.example'),
    cookie('kept', 'same', '.account.example', -1), cookie('foreign', 'value', '.foreign.invalid')];
  assert.deepEqual(changedCookies([kept, rotated, removed], after, 'www.account.example'),
    [cookie('session', 'new'), cookie('fresh', 'value', 'www.account.example'), { ...removed, expires: 1 }]);
  assert.deepEqual(changedCookies([kept], [{ ...kept, expires: 0.4 - 1 }], 'www.account.example'), []);
  assert.deepEqual(changedCookies([kept], [{ ...kept, expires: 1_900_000_000 }], 'www.account.example'), [{ ...kept, expires: 1_900_000_000 }]);
});

test('one exchange reads the cookies for its URL, writes back only changes and always disposes', async () => {
  const session = cookie('session', 'synthetic');
  let jar = [session], disposed = 0;
  const reads = [], writes = [];
  const dependencies = {
    readCookies: async urls => { reads.push(urls); return [session]; },
    writeCookies: async cookies => { writes.push(cookies); return cookies.length; },
    createContext: async options => {
      assert.deepEqual(options, { storageState: { cookies: [session], origins: [] }, proxy: { server: 'http://127.0.0.1:17897' } });
      return { storageState: async () => ({ cookies: jar, origins: [] }), dispose: async () => { disposed++; } };
    },
  };
  const url = 'https://www.account.example/account';
  assert.equal(await withSharedCookies(url, 'http://127.0.0.1:17897', async () => 'answer', dependencies), 'answer');
  assert.deepEqual(reads, [[url]]); assert.deepEqual(writes, []);
  jar = [cookie('session', 'rotated')];
  await withSharedCookies(url, 'http://127.0.0.1:17897', async () => 'answer', dependencies);
  assert.deepEqual(writes, [[cookie('session', 'rotated')]]);
  await assert.rejects(withSharedCookies(url, 'http://127.0.0.1:17897', async () => { throw Error('transport'); }, dependencies), /transport/);
  assert.equal(writes.length, 1); assert.equal(disposed, 3);
});
