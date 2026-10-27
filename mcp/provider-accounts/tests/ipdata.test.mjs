import test from 'node:test';
import assert from 'node:assert/strict';
import { ipdataStatus, ipdataObservation, verifyIpdata, ipdataAccountIdentity, checkIpdataAccount } from '../ipdata.mjs';

const key = 'a'.repeat(64);
const email = 'fixture@example.invalid';
const token = 'fixture.access.token';
const valid = { ip: '1.1.1.1', country_code: 'AU', privateField: 'not returned',
  threat: { is_proxy: false, is_tor: false, is_datacenter: true, is_threat: false, is_known_abuser: false, is_known_attacker: false } };
const identity = { Username: 'not returned', UserAttributes: Object.entries({ email, email_verified: 'true',
  'custom:api_key': key, 'custom:billing_plan': 'free', sub: 'not returned' }).map(([Name, Value]) => ({ Name, Value })) };
const savedState = { cookies: [], origins: [{ origin: 'https://dashboard.ipdata.co',
  localStorage: [{ name: 'CognitoIdentityServiceProvider.fixture.accessToken', value: token }] }] };

function secrets(state = savedState, account = { email }) {
  return async path => ({ secret: path.endsWith('credentials.json') ? JSON.stringify(account) :
    path.endsWith('-http.json') ? JSON.stringify(state) : key });
}

test('ipdata local readiness accepts session-sized files without claiming live authentication', async () => {
  let checks = 0;
  const result = await ipdataStatus({ inspectSecret: async (path, policy) => {
    checks++;
    return { usable: path.endsWith('-http.json') ? policy.maxBytes >= 8192 : true };
  } });
  assert.equal(checks, 3);
  assert.equal(result.httpSessionSaved, true);
  assert.equal(result.liveVerified, false);
});

test('ipdata risk observation binds the target, projects flags and leaves absent VPN unknown', () => {
  const result = ipdataObservation(200, valid);
  assert.equal(result.usable, true);
  assert.equal(result.riskFactors.is_proxy, false);
  assert.equal(result.riskFactors.is_datacenter, true);
  assert.equal(result.riskFactors.is_vpn, null);
  assert.equal(JSON.stringify(result).includes('not returned'), false);
  for (const body of [null, [], {}, { ...valid, ip: '8.8.8.8' }, { ...valid, country_code: 'A\n' },
    { ...valid, error: 'private error' }, { ...valid, message: 'quota exhausted' },
    { ...valid, threat: {} }, { ...valid, threat: [] }, { ...valid, threat: { is_proxy: 'false' } }]) {
    assert.deepEqual(ipdataObservation(200, body), { usable: false, status: 'invalid_response' });
  }
  assert.deepEqual(ipdataObservation(429, valid), { usable: false, status: 'rate_limited' });
  assert.deepEqual(ipdataObservation(403, valid), { usable: false, status: 'http_403' });
});

test('ipdata official probe makes one bounded fixed-target request and never returns its key', async () => {
  let calls = 0;
  const result = await verifyIpdata('VERIFY_FREE_API', {
    readSecret: async (_path, policy) => { assert.equal(policy.validate(key), true); return { secret: key }; },
    request: async options => {
      calls++;
      assert.equal(options.url, `https://api.ipdata.co/1.1.1.1?api-key=${key}`);
      assert.equal(options.maxRedirects, 0);
      assert.equal(options.timeoutMs, 10000);
      assert.equal(options.maxBytes, 262144);
      return { status: 200, contentType: 'application/json', body: Buffer.from(JSON.stringify(valid)) };
    },
  });
  assert.equal(calls, 1);
  assert.equal(result.usable, true);
  assert.equal(JSON.stringify(result).includes(key), false);
  await assert.rejects(verifyIpdata('NO', { readSecret: async () => assert.fail('unexpected secret read') }));
});

test('ipdata probe rejects HTML and malformed bodies and redacts transport failures', async () => {
  const dependencies = { readSecret: async () => ({ secret: key }) };
  for (const [contentType, body] of [['text/html', JSON.stringify(valid)], ['application/json', '{']]) {
    dependencies.request = async () => ({ status: 200, contentType, body: Buffer.from(body) });
    assert.equal((await verifyIpdata('VERIFY_FREE_API', dependencies)).status, 'invalid_response');
  }
  dependencies.request = async () => { throw new Error(`secret URL ${key}`); };
  const result = await verifyIpdata('VERIFY_FREE_API', dependencies);
  assert.equal(result.status, 'network_error');
  assert.equal(JSON.stringify(result).includes(key), false);
});

test('ipdata account identity binds exact email, compares the key and rejects ambiguous attributes', () => {
  const result = ipdataAccountIdentity(200, identity, email, key);
  assert.equal(result.authenticated, true);
  assert.equal(result.emailVerified, true);
  assert.equal(result.plan, 'free');
  assert.equal(result.keyMatchesReporter, true);
  assert.equal(result.mfaEnrollmentObserved, false);
  assert.equal(JSON.stringify(result).includes(email), false);
  assert.equal(JSON.stringify(result).includes(key), false);
  assert.equal(ipdataAccountIdentity(200, identity, email, 'b'.repeat(64)).keyMatchesReporter, false);
  assert.equal(ipdataAccountIdentity(200, { ...identity, UserMFASettingList: ['SOFTWARE_TOKEN_MFA'] }, email, key).mfaEnrollmentObserved, true);
  for (const body of [null, [], {}, { ...identity, UserAttributes: [...identity.UserAttributes, identity.UserAttributes[0]] },
    { ...identity, UserAttributes: [{ Name: 'email', Value: 123 }] }]) {
    assert.equal(ipdataAccountIdentity(200, body, email, key).authenticated, false);
  }
  assert.equal(ipdataAccountIdentity(200, identity, 'foreign@example.invalid', key).authenticated, false);
  assert.equal(ipdataAccountIdentity(400, { __type: 'NotAuthorizedException', message: token }, email, key).state, 'login_required');
});

test('ipdata account check uses one read-only HTTP operation and disposes the session', async () => {
  let calls = 0, disposed = 0;
  const result = await checkIpdataAccount({ readSecret: secrets(), createContext: async () => ({
    post: async (url, options) => {
      calls++;
      assert.equal(url, 'https://cognito-idp.us-east-1.amazonaws.com/');
      assert.equal(options.headers['X-Amz-Target'], 'AWSCognitoIdentityProviderService.GetUser');
      assert.deepEqual(options.data, { AccessToken: token });
      assert.equal(options.maxRedirects, 0);
      assert.equal(options.maxRetries, 0);
      assert.equal(options.timeout, 10000);
      return { status: () => 200, headers: () => ({ 'content-type': 'application/x-amz-json-1.1' }),
        body: async () => Buffer.from(JSON.stringify(identity)) };
    }, dispose: async () => { disposed++; },
  }) });
  assert.equal(calls, 1);
  assert.equal(disposed, 1);
  assert.equal(result.authenticated, true);
  for (const secret of [token, key, email]) assert.equal(JSON.stringify(result).includes(secret), false);
});

test('ipdata account check stops ambiguous or foreign saved state before HTTP', async () => {
  let calls = 0;
  const createContext = async () => { calls++; throw new Error('unexpected HTTP'); };
  for (const state of [{}, { origins: [] }, { origins: [{ ...savedState.origins[0], origin: 'https://foreign.invalid' }] },
    { origins: [...savedState.origins, ...savedState.origins] },
    { origins: [{ ...savedState.origins[0], localStorage: [...savedState.origins[0].localStorage, ...savedState.origins[0].localStorage] }] }]) {
    const result = await checkIpdataAccount({ readSecret: secrets(state), createContext });
    assert.equal(result.state, 'session_unavailable');
  }
  const missing = await checkIpdataAccount({ readSecret: secrets(savedState, {}), createContext });
  assert.equal(missing.state, 'session_unavailable');
  assert.equal(calls, 0);
});

test('ipdata account check handles expired state, bad content, redirects and errors without secret output', async () => {
  let disposed = 0;
  const cases = [
    [400, 'application/x-amz-json-1.1', JSON.stringify({ __type: 'NotAuthorizedException', message: token }), 'login_required'],
    [200, 'text/html', JSON.stringify(identity), 'unconfirmed'],
    [200, 'application/json', '{', 'unconfirmed'],
    [200, 'application/json', ' '.repeat(65537), 'unconfirmed'],
    [302, 'text/html', 'must not read', 'unconfirmed'],
    [0, '', '', 'session_unavailable'],
  ];
  for (const [status, contentType, body, expected] of cases) {
    const result = await checkIpdataAccount({ readSecret: secrets(), createContext: async () => ({
      post: async () => {
        if (!status) throw new Error(token);
        return { status: () => status, headers: () => ({ 'content-type': contentType }), body: async () => {
          assert.notEqual(status, 302); return Buffer.from(body);
        } };
      }, dispose: async () => { disposed++; },
    }) });
    assert.equal(result.state, expected);
    assert.equal(JSON.stringify(result).includes(token), false);
  }
  assert.equal(disposed, cases.length);
});
