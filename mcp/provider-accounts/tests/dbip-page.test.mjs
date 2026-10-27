import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {dbipPageObservation, dbipPageProxy, readDbipPage} from '../dbip-page.mjs';

const ip = '198.51.100.23';
const fixture = JSON.parse(readFileSync(new URL('../../../test/fixtures/dbip/public-page.json', import.meta.url)));

test('public page binds the exact record and projects only its explicit risk label', () => {
  for (const label of ['LOW', 'MEDIUM', 'HIGH']) {
    assert.deepEqual(dbipPageObservation({...fixture, text: fixture.text.replace('LOW', label)}, ip),
      {status: 'ok', ipAddress: ip, threatLevel: label.toLowerCase()});
  }
  assert.deepEqual(dbipPageObservation({...fixture, text: fixture.text.replace(/Estimated[^\n]+/, '')}, ip), {status: 'not_provided'});
  for (const patch of [
    {url: 'https://db-ip.com/198.51.100.24'}, {title: '198.51.100.24 - Example'}, {title: 1},
    {headings: {}}, {headings: [...fixture.headings, ...fixture.headings]},
    {headings: [{level: 'h1', text: '198.51.100.24 - IP Address Geolocation'}]},
    {text: fixture.text + '\n' + ip}, {text: fixture.text + '\nEstimated threat level for this IP address is HIGH'},
    {text: fixture.text.replace(ip, '198.51.100.24')}, {text: 'x'.repeat(24001)},
    {httpStatus: 403}, {ok: false}, {challenge: true}, {truncated: true},
    {cleanupConfirmed: false}, {launchMode: 'visible'}, {sessionMode: 'persistent'},
    {nativeRecovery: {outcome: 'not_ready', recipe: 'dbip-public-ip'}}
  ]) assert.deepEqual(dbipPageObservation({...fixture, ...patch}, ip), {status: 'invalid_response'});
  for (const target of [null, '8.8.8.8', '::1'])
    assert.deepEqual(dbipPageObservation(fixture, target), {status: 'invalid_response'});
});

test('browser route matches HTTPS curl precedence and rejects unsupported bypass/credentials', () => {
  assert.equal(dbipPageProxy({HTTP_PROXY: 'http://unused:8888'}), undefined);
  assert.equal(dbipPageProxy({https_proxy: 'http://127.0.0.1:12345', HTTPS_PROXY: 'http://unused:8888', NO_PROXY: 'localhost,127.0.0.1,::1'}), 'http://127.0.0.1:12345');
  assert.equal(dbipPageProxy({ALL_PROXY: 'socks5://127.0.0.1:12345'}), 'socks5://127.0.0.1:12345');
  for (const env of [
    {HTTPS_PROXY: 'http://user:secret@127.0.0.1:12345'}, {HTTPS_PROXY: 'ftp://127.0.0.1:12345'},
    {HTTPS_PROXY: 'invalid'}, {HTTPS_PROXY: 'http://127.0.0.1:12345/path'},
    {HTTPS_PROXY: 'http://127.0.0.1:12345', NO_PROXY: '*'},
    {HTTPS_PROXY: 'http://127.0.0.1:12345', no_proxy: 'db-ip.com'}
  ]) assert.throws(() => dbipPageProxy(env), /^Error: route_unsupported$/);
});

test('one bounded public read uses no account session and preserves route and cancellation', async () => {
  const signal = new AbortController().signal;
  for (const env of [{}, {https_proxy: 'http://127.0.0.1:12345'}]) {
    let count = 0;
    const result = await readDbipPage(ip, {env, signal, read: async (options, context) => {
      count++;
      assert.deepEqual(options, {url: `https://db-ip.com/${ip}`, backend: 'real-chrome-cdp', timeoutMs: 30000, maxChars: 24000, maxLinks: 0});
      assert.deepEqual(context, {proxyServer: env.https_proxy, signal});
      return fixture;
    }});
    assert.equal(count, 1);
    assert.equal(result.status, 'ok');
  }
  const noRead = async () => {throw Error('unexpected read');};
  assert.deepEqual(await readDbipPage(ip, {signal: AbortSignal.abort(), read: noRead}), {status: 'cancelled'});
  assert.deepEqual(await readDbipPage('::1', {read: noRead}), {status: 'route_unsupported'});
  assert.deepEqual(await readDbipPage(ip, {env: {HTTPS_PROXY: 'invalid'}, read: noRead}), {status: 'route_unsupported'});
});

test('unavailable pages never yield a clean result or expose raw errors', async () => {
  for (const [response, status] of [
    [{httpStatus: 429}, 'rate_limited'], [{httpStatus: 403}, 'cloudflare_blocked'],
    [{challenge: true}, 'cloudflare_blocked'], [{error: {code: 'CLEANUP_FAILED'}}, 'cleanup_unverified'],
    [{error: {code: 'NATIVE_NOT_READY'}}, 'timeout'], [null, 'invalid_response']
  ]) assert.deepEqual(await readDbipPage(ip, {env: {}, read: async () => response}), {status});
  assert.deepEqual(await readDbipPage(ip, {env: {}, read: async () => {throw Error('private raw body');}}), {status: 'browser_unavailable'});
});

test('CLI refuses missing consent and malformed input without importing a browser', () => {
  const script = fileURLToPath(new URL('../dbip-page.mjs', import.meta.url));
  for (const [args, input, status] of [
    [[], '{}', 'confirmation_required'], [['--confirm-network-lookup', 'extra'], '{}', 'confirmation_required'],
    [['--confirm-network-lookup'], '{', 'invalid_input'],
    [['--confirm-network-lookup'], JSON.stringify({ip, cookie: 'secret'}), 'invalid_input'],
    [['--confirm-network-lookup'], JSON.stringify({ip: 'not-ip'}), 'route_unsupported']
  ]) {
    const result = spawnSync(process.execPath, [script, ...args], {input, encoding: 'utf8', timeout: 3000});
    assert.equal(result.error, undefined);
    assert.equal(result.stderr, '');
    assert.deepEqual(JSON.parse(result.stdout), {status});
  }
});
