import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { publicProviderContext, verifyPublicProvider } from '../public-api.mjs';

const dbip = JSON.parse(await readFile(new URL('../../../test/fixtures/dbip/free.json', import.meta.url), 'utf8'));
const whois = JSON.parse(await readFile(new URL('../../../test/fixtures/ipwhois/valid.json', import.meta.url), 'utf8'));

test('free provider projections retain context and never accept unexpected premium security flags', () => {
  const result = publicProviderContext('dbip', { ...dbip, threatLevel: 'low', isProxy: false }, dbip.ipAddress);
  assert.equal(result.city, 'Example City');
  assert.equal(result.threatLevel, undefined);
  assert.equal(result.isProxy, undefined);
  const network = publicProviderContext('ipwhois', { ...whois, security: { vpn: false } }, whois.ip);
  assert.equal(network.organization, whois.connection.org);
  assert.equal(network.security, undefined);
  for (const body of [null, [], { ...dbip, ipAddress: '8.8.8.8' }, { ...dbip, countryCode: ['US'] }, { ...dbip, city: '\u001b[31m' }, { ...dbip, errorCode: 'QUOTA_EXCEEDED' }]) assert.equal(publicProviderContext('dbip', body, dbip.ipAddress), null);
  for (const connection of ['provider', [], { ...whois.connection, asn: ['64500'] }]) assert.equal(publicProviderContext('ipwhois', { ...whois, connection }, whois.ip), null);
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
    assert.equal(result.context,undefined);
  }
  let calls=0;
  const request=async()=>{calls++;throw new Error('raw response canary');};
  assert.equal((await verifyPublicProvider('dbip','VERIFY_FREE_API',request)).status,'network_error');
  assert.equal(calls,1);
  await assert.rejects(verifyPublicProvider('unknown','VERIFY_FREE_API',request));
  await assert.rejects(verifyPublicProvider('dbip','',request));
  assert.equal(calls,1);
});
