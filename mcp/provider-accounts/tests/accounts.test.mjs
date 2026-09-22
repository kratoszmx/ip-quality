import assert from 'node:assert/strict';
import test from 'node:test';
import { runInNewContext } from 'node:vm';
import { accountUrl, accountPagePath, accountNetworkOptions, accountRouteMatches, assertAccountOrigin, classifyAccountPage, ipapiDashboardAccepted, redactAccountText, ipapiKeyAccepted } from '../policy.mjs';
import { submitReviewedSignup } from '../signup.mjs';

test('account origins and surfaces reject credential-bearing and foreign URLs', () => {
  assert.equal(accountUrl('ipapi', 'signup'), 'https://ipapi.is/app/signup');
  for (const url of ['https://ipapi.is.evil.test/', 'https://user:pass@ipapi.is/', 'http://ipapi.is/']) assert.throws(() => assertAccountOrigin('ipapi', url));
  assert.throws(() => accountUrl('constructor', 'signup'));
  assert.throws(() => accountUrl('cloudflare', 'billing'));
  assert.throws(() => accountUrl('ipapi', 'security'));
});

test('explicit direct Chrome disables the OS proxy and overrides inherited HTTP proxy', () => {
  const direct = accountNetworkOptions({ PROVIDER_ACCOUNTS_PROXY: 'DIRECT', HTTPS_PROXY: 'http://127.0.0.1:7897' });
  assert.equal(direct.proxyServer, undefined);
  assert.deepEqual(direct.chromeArgs, ['--no-proxy-server']);
  assert.equal(accountRouteMatches('/Chrome --user-data-dir=/private --no-proxy-server', direct), true);
  assert.equal(accountRouteMatches('/Chrome --user-data-dir=/private', direct), false);
  assert.equal(accountRouteMatches('/Chrome --no-proxy-server --proxy-server=http://127.0.0.1:7897', direct), false);
  assert.equal(accountRouteMatches('/Chrome --no-proxy-server --proxy-auto-detect', direct), false);
});

test('an explicit account proxy cannot silently reuse a differently routed browser', () => {
  const routing = accountNetworkOptions({ PROVIDER_ACCOUNTS_PROXY: 'http://127.0.0.1:12345' });
  assert.equal(accountRouteMatches('/Chrome --proxy-server=http://127.0.0.1:12345', routing), true);
  assert.equal(accountRouteMatches('/Chrome --proxy-server=http://127.0.0.1:7897', routing), false);
  assert.equal(accountRouteMatches('/Chrome --no-proxy-server', routing), false);
  for (const value of ['https://user:pass@proxy.invalid/', 'file:///private', 'http://proxy.invalid/path']) assert.throws(() => accountNetworkOptions({ PROVIDER_ACCOUNTS_PROXY: value }));
});

test('provider failures, verification and saved forms never become authentication', () => {
  assert.equal(classifyAccountPage({ text: 'Account dashboard Sign out', hasPassword: false, challenge: true }), 'human_verification_required');
  assert.equal(classifyAccountPage({ text: 'We could not complete your registration from this connection.', hasPassword: true }), 'registration_connection_blocked');
  assert.equal(classifyAccountPage({ text: 'Verify your email', hasPassword: false }), 'email_verification_required');
  assert.equal(classifyAccountPage({ text: 'Your account is not activated yet. We have just sent a new activation link.', hasPassword: true }), 'email_verification_required');
  assert.equal(classifyAccountPage({ text: 'Dashboard', hasPassword: false }), 'unconfirmed');
  assert.equal(classifyAccountPage({ text: 'Account dashboard Sign out', hasPassword: false }), 'authenticated');
  assert.equal(classifyAccountPage({ text: 'Sign up', hasPassword: true, submitted: true }), 'submission_unconfirmed');
});

test('dashboard redaction covers short API keys, account emails, OTPs and explicit passwords', () => {
  const text = redactAccountText('email a@fixture.invalid API abcdef0123456789 OTP 123456 password canary otpauth://totp/fixture?secret=ABCDEF', ['canary']);
  for (const value of ['a@fixture.invalid', 'abcdef0123456789', '123456', 'canary', 'secret=ABCDEF']) assert.ok(!text.includes(value));
});

test('page metadata omits Cloudflare account ids and verification query tokens', () => {
  const id = '1234567890abcdef1234567890abcdef';
  assert.equal(accountPagePath('cloudflare', `https://dash.cloudflare.com/${id}/home?token=private`), '/[private account]/home');
  assert.throws(() => accountPagePath('cloudflare', 'https://foreign.invalid/home'));
});

test('key validation requires the keyed contract and exact target with successful HTTP', () => {
  const body = { ip: '1.1.1.1', company: { name: 'Fixture' }, is_proxy: false };
  assert.equal(ipapiKeyAccepted(200, body, '1.1.1.1'), true);
  for (const status of [301, 403, 429, 500]) assert.equal(ipapiKeyAccepted(status, body, '1.1.1.1'), false);
  assert.equal(ipapiKeyAccepted(200, { ...body, docs: 'anonymous' }, '1.1.1.1'), false);
  assert.equal(ipapiKeyAccepted(200, body, '8.8.8.8'), false);
  for (const change of [{ error_code: 'QUOTA_EXCEEDED' }, { company: [] }, { docs: '' }, { is_proxy: 'false' }]) assert.equal(ipapiKeyAccepted(200, { ...body, ...change }, '1.1.1.1'), false);
});

test('ipapi icon-only logout verifies the exact saved account on the observed dashboard', () => {
  const email = 'account@fixture.invalid';
  const value = { url: 'https://ipapi.is/app/home', logoutUrl: 'https://ipapi.is/app/logout', email, keyCount: 1, hasPassword: false };
  assert.equal(accountUrl('ipapi', 'dashboard'), value.url);
  assert.equal(ipapiDashboardAccepted(value, email), true);
  assert.equal(classifyAccountPage({ text: 'Account Details API Credentials', hasPassword: false, authenticatedAccount: true }), 'authenticated');
  for (const change of [{ url: 'https://ipapi.is/app/signup' }, { url: 'https://foreign.invalid/app/home' }, { logoutUrl: 'https://foreign.invalid/app/logout' }, { email: 'different@fixture.invalid' }, { keyCount: 0 }, { keyCount: 2 }, { hasPassword: true }]) {
    assert.equal(ipapiDashboardAccepted({ ...value, ...change }, email), false);
  }
  assert.equal(ipapiDashboardAccepted(value, undefined), false);
  assert.equal(classifyAccountPage({ text: 'Account dashboard Sign out', hasPassword: false, authenticatedAccount: false, allowTextAuthentication: false }), 'unconfirmed');
  assert.equal(classifyAccountPage({ text: 'Verify your email', hasPassword: false, authenticatedAccount: true }), 'email_verification_required');
});

function signupPage({ action = '/app/signup', method = 'post', enabled = true, clickFails = false } = {}) {
  const events = [];
  const button = { count: async () => 1, isEnabled: async () => enabled, click: async () => { events.push('submit'); if (clickFails) throw new Error('timeout'); } };
  const form = { filter() { return this; }, count: async () => 1,
    getAttribute: async name => name === 'action' ? action : method,
    getByRole: () => button,
    locator: () => ({ fill: async () => events.push('fill'), selectOption: async () => events.push('country') }),
  };
  return { events, page: { url: () => 'https://ipapi.is/app/signup', locator: () => form, waitForFunction: async () => events.push('settled-outcome') } };
}

test('signup waits for the asynchronous outcome after exactly one submission', async () => {
  const { events, page } = signupPage();
  await submitReviewedSignup(page, 'ipapi', { email: 'a@fixture.invalid', password: 'synthetic' }, 'Hong Kong', async () => events.push('reserve'));
  assert.deepEqual(events, ['fill', 'fill', 'country', 'reserve', 'submit', 'settled-outcome']);
  page.waitForFunction = async () => { throw new Error('Outcome timeout'); };
  const other = signupPage(); other.page.waitForFunction = page.waitForFunction;
  await submitReviewedSignup(other.page, 'ipapi', { email: 'a@fixture.invalid', password: 'synthetic' }, 'Hong Kong', async () => {});
  assert.equal(other.events.filter(event => event === 'submit').length, 1);
});

test('an ipapi activation notice completes the signup wait without another submission', async () => {
  const { events, page } = signupPage();
  page.waitForFunction = async (predicate, initialPath) => {
    const evaluate = text => runInNewContext(`(${predicate.toString()})(initialPath)`, { initialPath, location: { pathname: initialPath }, document: { body: { innerText: text } } });
    assert.equal(evaluate('Create Free Account'), false);
    assert.equal(evaluate('We have just sent a new activation link. Please activate your account.'), true);
  };
  await submitReviewedSignup(page, 'ipapi', { email: 'a@fixture.invalid', password: 'synthetic' }, 'Hong Kong', async () => {});
  assert.equal(events.filter(event => event === 'submit').length, 1);
});

test('foreign, changed, GET and disabled signup forms stop before credentials are filled', async () => {
  for (const options of [{ action: 'https://evil.test/' }, { action: '/app/upgrade' }, { method: 'get' }, { enabled: false }]) {
    const { events, page } = signupPage(options);
    await assert.rejects(submitReviewedSignup(page, 'ipapi', { email: 'a@fixture.invalid', password: 'synthetic' }, 'Hong Kong', async () => events.push('reserve')));
    assert.deepEqual(events, []);
  }
});

test('an ambiguous submission consumes its one-use reservation and is never retried', async () => {
  const { events, page } = signupPage({ clickFails: true });
  await assert.rejects(submitReviewedSignup(page, 'ipapi', { email: 'a@fixture.invalid', password: 'synthetic' }, 'Hong Kong', async () => events.push('reserve')));
  assert.deepEqual(events, ['fill', 'fill', 'country', 'reserve', 'submit']);
});

test('concurrent or previously reserved registration never submits', async () => {
  const { events, page } = signupPage();
  await assert.rejects(submitReviewedSignup(page, 'ipapi', { email: 'a@fixture.invalid', password: 'synthetic' }, 'Hong Kong', async () => { throw new Error('reserved'); }));
  assert.ok(!events.includes('submit'));
});
