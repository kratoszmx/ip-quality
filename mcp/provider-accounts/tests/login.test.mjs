import assert from 'node:assert/strict';
import test from 'node:test';
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

test('ipapi bot-login restriction stops before any saved credentials, browser or network use', async () => {
  assert.equal(acceptsLoginForm('ipapi', { url: 'https://ipapi.is/app/', action: '/app/', method: 'post', fields: ['email', 'pass'], button: 'Sign In' }), false);
  const result = await loginAccount('ipapi', 'USE_SAVED_ACCOUNT_CREDENTIALS');
  assert.equal(result.state, 'manual_login_required');
  assert.equal(result.liveAuthenticationChecked, false);
  assert.equal(result.credentialsSubmitted, false);
  assert.equal(result.retryAutomatically, false);
});
