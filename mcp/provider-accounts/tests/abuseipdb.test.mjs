import test from 'node:test';
import assert from 'node:assert/strict';
import { abuseipdbObservation, verifyAbuseipdb } from '../abuseipdb.mjs';

const valid = { data: { ipAddress: '1.1.1.1', abuseConfidenceScore: 0, countryCode: 'AU', ownerPrivateField: 'not returned' } };
test('AbuseIPDB observation binds the target, preserves zero, and projects no account data', () => {
  assert.deepEqual(abuseipdbObservation(200, valid), { usable: true, status: 'ok', target: '1.1.1.1', abuseConfidenceScore: 0, countryCode: 'AU' });
  for (const body of [null, {}, { errors: [], ...valid }, { data: { ...valid.data, ipAddress: '8.8.8.8' } },
    { data: { ...valid.data, abuseConfidenceScore: '0' } }, { data: { ...valid.data, abuseConfidenceScore: 101 } },
    { data: { ...valid.data, countryCode: 'A\n' } }]) {
    assert.equal(abuseipdbObservation(200, body).usable, false);
  }
  assert.deepEqual(abuseipdbObservation(429, valid), { usable: false, status: 'rate_limited' });
  assert.equal(abuseipdbObservation(401, valid).usable, false);
});

test('AbuseIPDB probe uses one fixed read, a private header and no redirect or output secret', async () => {
  let calls = 0;
  const result = await verifyAbuseipdb('VERIFY_FREE_API', {
    readSecret: async (_path, policy) => { assert.equal(policy.validate('fixturekey123'), true); return { secret: 'fixturekey123' }; },
    request: async options => {
      calls++;
      assert.equal(options.url, 'https://api.abuseipdb.com/api/v2/check?ipAddress=1.1.1.1&maxAgeInDays=90');
      assert.equal(options.headers.Key, 'fixturekey123');
      assert.equal(options.maxRedirects, 0);
      assert.equal(options.timeoutMs, 10000);
      assert.equal(options.maxBytes, 65536);
      return { status: 200, contentType: 'application/json', body: Buffer.from(JSON.stringify(valid)) };
    },
  });
  assert.equal(calls, 1);
  assert.equal(result.usable, true);
  assert.equal(JSON.stringify(result).includes('fixturekey123'), false);
});

test('AbuseIPDB probe rejects unconfirmed requests before touching private files', async () => {
  await assert.rejects(verifyAbuseipdb('NO', { readSecret: async () => { assert.fail('unexpected secret read'); } }));
});

test('AbuseIPDB does not interpret HTML or transport failure as an available score', async () => {
  const dependencies = { readSecret: async () => ({ secret: 'fixturekey123' }),
    request: async () => ({ status: 200, contentType: 'text/html', body: Buffer.from(JSON.stringify(valid)) }) };
  assert.equal((await verifyAbuseipdb('VERIFY_FREE_API', dependencies)).status, 'invalid_response');
  dependencies.request = async () => { throw new Error('transport failed'); };
  await assert.rejects(verifyAbuseipdb('VERIFY_FREE_API', dependencies));
});
