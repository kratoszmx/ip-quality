import assert from 'node:assert/strict';
import test from 'node:test';
import { accountUrl, accountPagePath, assertAccountOrigin, classifyAccountPage, redactAccountText, ipapiKeyAccepted } from '../policy.mjs';
import { submitReviewedSignup } from '../signup.mjs';

test('account origins and surfaces reject credential-bearing and foreign URLs', () => {
  assert.equal(accountUrl('ipapi', 'signup'), 'https://ipapi.is/app/signup');
  for (const url of ['https://ipapi.is.evil.test/', 'https://user:pass@ipapi.is/', 'http://ipapi.is/']) assert.throws(() => assertAccountOrigin('ipapi', url));
  assert.throws(() => accountUrl('constructor', 'signup'));
  assert.throws(() => accountUrl('cloudflare', 'billing'));
});

test('provider failures, verification and saved forms never become authentication', () => {
  assert.equal(classifyAccountPage({ text: 'Account dashboard Sign out', hasPassword: false, challenge: true }), 'human_verification_required');
  assert.equal(classifyAccountPage({ text: 'We could not complete your registration from this connection.', hasPassword: true }), 'registration_connection_blocked');
  assert.equal(classifyAccountPage({ text: 'Verify your email', hasPassword: false }), 'email_verification_required');
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
