import assert from 'node:assert/strict';
import test from 'node:test';
import { runInNewContext } from 'node:vm';
import { acceptsLoginForm, loginAccount, loginFailureState } from '../login.mjs';

test('login rejection and verification are explicit rather than reported as authenticated', () => {
  assert.equal(loginFailureState({ challenge: true, text: '', hasPassword: true }), 'human_verification_required');
  assert.equal(loginFailureState({ challenge: false, text: 'Invalid password', hasPassword: true }), 'credential_rejected');
  assert.equal(loginFailureState({ challenge: false, text: 'Enter your authenticator verification code', hasPassword: false }), 'secondary_verification_required');
  assert.equal(loginFailureState({ challenge: false, text: 'Verify your email', hasPassword: false }), 'email_verification_required');
  assert.equal(loginFailureState({ challenge: false, text: '', hasPassword: false, path: '/app/accept-terms' }), 'terms_acceptance_required');
});

test('saved login accepts only the reviewed origin, POST action and unique credential fields', async () => {
  for (const [provider, url, password, button] of [
    ['cloudflare', 'https://dash.cloudflare.com/login', 'password', 'Sign in'],
    ['abuseipdb', 'https://www.abuseipdb.com/login', 'password', 'Login'],
  ]) {
    const form = { url, action: url, method: 'post', fields: ['email', password], button };
    assert.equal(acceptsLoginForm(provider, form), true);
    for (const change of [{ url: 'https://foreign.invalid/login' }, { action: 'https://foreign.invalid/login' },
      { action: '/register' }, { action: url.replace('https://', 'https://user:pass@') }, { method: 'get' }, { button: 'Register' }, { fields: ['email', 'email', password] }]) {
      assert.equal(acceptsLoginForm(provider, { ...form, ...change }), false);
    }
    await assert.rejects(loginAccount(provider, ''), /authorization/);
  }
});

test('login prepares normal verification before accepting a previous HTTP 403 or returning a remaining check', async () => {
  for (const pending of [false, true]) {
    let preparations = 0;
    const page = { url: () => 'https://dash.cloudflare.com/login',
      goto: async () => ({ status: () => 403 }), waitForFunction: async () => {},
      evaluate: async project => runInNewContext(`(${project.toString()})()`, {
        location: { pathname: '/login' }, document: {
          body: { innerText: 'Verify you are human' }, querySelectorAll: () => [{ value: 'synthetic-response' }],
          querySelector: () => ({}),
        },
      }),
      locator: () => ({ filter: () => ({ count: async () => 0 }) }),
    };
    const result = await loginAccount('cloudflare', 'USE_SAVED_ACCOUNT_CREDENTIALS', {
      privateAccount: async () => ({ email: 'fixture@example.test', password: 'synthetic-private-password' }),
      readHttpAccount: async () => ({ authenticated: false, state: 'login_required', httpStatus: 302 }),
      withSession: async (_provider, operation) => operation(page),
      prepareVerification: async (actualPage, origin) => {
        preparations++; assert.equal(actualPage, page); assert.equal(origin, 'https://dash.cloudflare.com');
        return { encountered: true, pending, attempted: true, clicked: true };
      },
    });
    assert.equal(preparations, 1);
    // A resolved check reaches form validation; the deliberately absent form
    // still prevents a password submission. A remaining check stays explicit.
    assert.equal(result.state, pending ? 'human_verification_required' : 'unrecognized_login_form');
    assert.equal(result.credentialsSubmitted, false);
    assert.equal(JSON.stringify(result).includes('synthetic-private-password'), false);
  }
});

for (const [name, identity, expectedState] of [
  ['valid session is reused over HTTP', { authenticated: true, state: 'authenticated', httpStatus: 200 }, 'authenticated'],
  ['expired session never starts a password login', { authenticated: false, state: 'login_required', httpStatus: 302 }, 'manual_login_required'],
  ['missing local session does not claim a live identity check', { authenticated: false, state: 'session_unavailable' }, 'manual_login_required'],
  ['suspended identity is preserved rather than accepted as usable', { authenticated: true, state: 'account_suspended', apiUsable: false, restriction: 'bot_login', httpStatus: 200 }, 'account_suspended'],
]) {
  test(`ipapi ${name}`, async () => {
    assert.equal(acceptsLoginForm('ipapi', { url: 'https://ipapi.is/app/', action: '/app/', method: 'post', fields: ['email', 'pass'], button: 'Sign In' }), false);
    const calls = [];
    const result = await loginAccount('ipapi', 'USE_SAVED_ACCOUNT_CREDENTIALS', {
      privateAccount: async provider => { calls.push(['account', provider]); return { email: 'owner@example.invalid' }; },
      readHttpAccount: async (provider, email) => { calls.push(['http', provider, email]); return { provider, backend: 'http', ...identity }; },
      withSession: async () => { assert.fail('ipapi session reuse must never open a browser'); },
    });
    assert.deepEqual(calls, [['account', 'ipapi'], ['http', 'ipapi', 'owner@example.invalid']]);
    assert.equal(result.state, expectedState);
    assert.equal(result.authenticated, identity.authenticated);
    assert.equal(result.liveAuthenticationChecked, Number.isInteger(identity.httpStatus));
    assert.equal(result.credentialsSubmitted, false);
    if (expectedState !== 'authenticated') assert.equal(result.retryAutomatically, false);
    if (expectedState === 'account_suspended') {
      assert.equal(result.apiUsable, false);
      assert.equal(result.restriction, 'bot_login');
    }
  });
}
