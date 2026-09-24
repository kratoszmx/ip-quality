import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { publicProviderObservation, verifyPublicProvider } from '../public-api.mjs';

const dbip = JSON.parse(await readFile(new URL('../../../test/fixtures/dbip/free.json', import.meta.url), 'utf8'));
const whois = JSON.parse(await readFile(new URL('../../../test/fixtures/ipwhois/valid.json', import.meta.url), 'utf8'));
const demo = Object.fromEntries(await Promise.all(['dbip', 'ipwhois'].map(async provider => [provider,
  JSON.parse(await readFile(new URL(`../../../test/fixtures/${provider}/demo.json`, import.meta.url), 'utf8')),
])));
const guestPage = { status: 200, contentType: 'text/html', body: Buffer.from('<script data-api-key="fixture-guest-key"></script>') };

test('free provider projections retain context and never accept unexpected premium security flags', () => {
  const result = publicProviderObservation('dbip', { ...dbip, threatLevel: 'low', isProxy: false }, dbip.ipAddress);
  assert.equal(result.city, 'Example City');
  assert.equal(result.threatLevel, undefined);
  assert.equal(result.isProxy, undefined);
  const network = publicProviderObservation('ipwhois', { ...whois, security: { vpn: false } }, whois.ip);
  assert.equal(network.organization, whois.connection.org);
  assert.equal(network.security, undefined);
  for (const body of [null, [], { ...dbip, ipAddress: '8.8.8.8' }, { ...dbip, countryCode: ['US'] }, { ...dbip, city: '\u001b[31m' }, { ...dbip, errorCode: 'QUOTA_EXCEEDED' }]) assert.equal(publicProviderObservation('dbip', body, dbip.ipAddress), null);
  for (const connection of ['provider', [], { ...whois.connection, asn: ['64500'] }]) assert.equal(publicProviderObservation('ipwhois', { ...whois, connection }, whois.ip), null);
});

test('free verification uses one bounded fixed-target request without authentication or MFA', async () => {
  let calls = 0;
  const result = await verifyPublicProvider('dbip', 'VERIFY_FREE_API', async request => {
    calls++;
    assert.equal(request.url, 'https://api.db-ip.com/v2/free/1.1.1.1');
    assert.equal(request.maxRedirects, 0);
    assert.equal(request.maxBytes, 65536);
    assert.equal(request.headers, undefined);
    return { status: 200, contentType: 'application/json; charset=utf-8', body: Buffer.from(JSON.stringify({ ...dbip, ipAddress: '1.1.1.1' })) };
  });
  assert.equal(calls, 1);
  assert.equal(result.usable, true);
  assert.equal(result.requiresAccount, false);
  assert.equal(result.twoFactor, 'not_applicable_no_account');
  assert.equal(result.riskScoreAvailable, false);
  assert.equal(result.documentedDailyQuota, 500);
});

test('HTTP failures, redirects, invalid JSON and wrong targets cannot become free API proof', async () => {
  for (const response of [
    { status: 429 }, { status: 302 }, { status: 403 },
    { status: 200, contentType: 'text/html', body: Buffer.from('<html>blocked</html>') },
    { status: 200, contentType: 'application/json', body: Buffer.from('{') },
    { status: 200, contentType: 'application/json', body: Buffer.from(JSON.stringify(dbip)) },
  ]) {
    let calls=0;
    const result=await verifyPublicProvider('dbip','VERIFY_FREE_API',async()=>{calls++;return response;});
    assert.equal(calls,1);
    assert.equal(result.usable,false);
    assert.equal(result.observation,undefined);
  }
  let calls=0;
  const request=async()=>{calls++;throw new Error('raw response canary');};
  assert.equal((await verifyPublicProvider('dbip','VERIFY_FREE_API',request)).status,'network_error');
  assert.equal(calls,1);
  await assert.rejects(verifyPublicProvider('unknown','VERIFY_FREE_API',request));
  await assert.rejects(verifyPublicProvider('dbip','',request));
  assert.equal(calls,1);
});

test('demo contracts expose real labels and booleans only for the exact target', () => {
  const dbipResult = publicProviderObservation('dbip', demo.dbip, '198.51.100.23', 'public_demo');
  assert.equal(dbipResult.threatLevel, 'low');
  assert.equal(dbipResult.score, undefined);
  const whoisResult = publicProviderObservation('ipwhois', demo.ipwhois, '198.51.100.23', 'public_demo');
  assert.deepEqual(whoisResult.security, { proxy: false, vpn: true, tor: false, hosting: true });
  assert.equal(publicProviderObservation('ipwhois', { ...demo.ipwhois, security: { vpn: 'false' } }, '198.51.100.23', 'public_demo'), null);
  assert.equal(publicProviderObservation('dbip', { ...demo.dbip, threatLevel: 0 }, '198.51.100.23', 'public_demo'), null);
  for (const provider of ['dbip', 'ipwhois']) assert.equal(publicProviderObservation(provider, demo[provider], '8.8.8.8', 'public_demo'), null);
  assert.deepEqual(publicProviderObservation('ipwhois', whois, whois.ip, 'public_demo').security, { proxy: null, vpn: null, tor: null, hosting: null });
});

test('HTTP 200 demo quota errors are unusable and never trigger retries or MFA', async () => {
  for (const provider of ['dbip', 'ipwhois']) {
    const body = await readFile(new URL(`../../../test/fixtures/${provider}/demo-rate-limited.json`, import.meta.url));
    let calls = 0;
    const result = await verifyPublicProvider(provider, 'VERIFY_FREE_API', async request => {
      calls++;
      assert.equal(request.maxRedirects, 0);
      if (provider === 'dbip' && calls === 1) {
        assert.equal(request.url, 'https://db-ip.com/api/core/');
        assert.equal(request.maxBytes, 262144);
        return guestPage;
      }
      assert.equal(request.url, provider === 'dbip' ? 'https://api.db-ip.com/v2/fixture-guest-key/self?convertCurrencies' : 'https://ipwhois.io/demo?ip=1.1.1.1');
      assert.equal(request.maxBytes, 65536);
      const origin = provider === 'dbip' ? 'https://db-ip.com' : 'https://ipwhois.io';
      assert.equal(request.headers.origin, origin);
      assert.equal(request.headers.referer, origin + '/');
      assert.match(request.headers['user-agent'], /Mozilla/);
      return { status: 200, contentType: 'application/json', body };
    }, 'public_demo');
    assert.equal(calls, provider === 'dbip' ? 2 : 1);
    assert.equal(result.usable, false);
    assert.equal(result.status, 'rate_limited');
    assert.equal(result.observation, undefined);
    assert.equal(result.riskLabelAvailable, false);
    assert.equal(result.riskFactorsAvailable, false);
    assert.equal(result.requiresAccount, false);
    assert.equal(result.twoFactor, 'not_applicable_no_account');
    assert.equal(result.documentedDailyQuota, null);
  }
});

test('demo verification distinguishes useful context from supplied risk fields', async () => {
  const responses = [
    ['dbip', { ...demo.dbip, ipAddress: '1.1.1.1' }, true, false],
    ['ipwhois', { ...demo.ipwhois, ip: '1.1.1.1' }, false, true],
    ['ipwhois', { ...whois, ip: '1.1.1.1' }, false, false],
  ];
  for (const [provider, body, label, factors] of responses) {
    const result = await verifyPublicProvider(provider, 'VERIFY_FREE_API', async request => request.url === 'https://db-ip.com/api/core/' ? guestPage : ({ status: 200, contentType: 'application/json', body: Buffer.from(JSON.stringify(body)) }), 'public_demo');
    assert.equal(result.usable, true);
    assert.equal(result.riskScoreAvailable, false);
    assert.equal(result.riskLabelAvailable, label);
    assert.equal(result.riskFactorsAvailable, factors);
    assert.equal(result.target, provider === 'dbip' ? 'request_egress' : '1.1.1.1');
    assert.equal(JSON.stringify(result).includes('fixture-guest-key'), false);
  }
});

test('DB-IP visitor demo stops at a failed page and never exposes a guest URL', async () => {
  for (const page of [
    { status: 429 }, { status: 302 },
    { ...guestPage, body: Buffer.from('<script data-api-key="bad/path"></script>') },
    { ...guestPage, body: Buffer.from('<html>changed page</html>') },
  ]) {
    let calls = 0;
    const result = await verifyPublicProvider('dbip', 'VERIFY_FREE_API', async () => { calls++; return page; }, 'public_demo');
    assert.equal(calls, 1);
    assert.equal(result.usable, false);
    assert.equal(result.observation, undefined);
  }
  let calls = 0;
  const result = await verifyPublicProvider('dbip', 'VERIFY_FREE_API', async () => {
    if (++calls === 1) return guestPage;
    throw new Error('https://api.db-ip.com/v2/fixture-guest-key/self');
  }, 'public_demo');
  assert.equal(calls, 2);
  assert.equal(result.status, 'network_error');
  assert.equal(JSON.stringify(result).includes('fixture-guest-key'), false);
});
