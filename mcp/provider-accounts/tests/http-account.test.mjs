import assert from 'node:assert/strict';
import test from 'node:test';
import { httpAccountIdentity, readHttpAccount } from '../http-account.mjs';

const email = 'fixture@example.test';
const html = `<input name="email" value="${email}"><input name="key" value="private"><a href="/app/logout">Logout</a>`;
test('ipapi account suspension remains explicit even with a valid saved login', () => {
  const notice = '<div>Your account has been banned: bot_login — Your account was suspended.</div>';
  const result = httpAccountIdentity('ipapi', 200, 'text/html', html + notice, email);
  assert.equal(result.authenticated, true);
  assert.equal(result.state, 'account_suspended');
  assert.equal(result.apiUsable, false);
  assert.equal(result.restriction, 'bot_login');
  assert.equal(httpAccountIdentity('ipapi', 200, 'text/html', html + `<script>${notice}</script>`, email).state, 'authenticated');
  assert.equal(httpAccountIdentity('ipapi', 200, 'text/html', html + `<template>${notice}</template>`, email).state, 'authenticated');
  assert.equal(httpAccountIdentity('ipapi', 200, 'text/html', html + '<div data-msg="your account was suspended"></div>', email).state, 'authenticated');
  assert.equal(httpAccountIdentity('ipapi', 200, 'text/html', notice, email).authenticated, false);
});
test('HTTP identity requires the matching server account, not a local state file or status 200', () => {
  assert.equal(httpAccountIdentity('ipapi', 200, 'text/html', html, email).authenticated, true);
  for (const [status, body, account] of [[403, html, email], [302, html, email], [200, html, 'other@example.test'],
    [200, `<script>${html}</script>`, email], [200, `${html}<input type="password">`, email], [200, `${html}<input type=password>`, email], [200, '<form>Login</form>', email]]) {
    assert.equal(httpAccountIdentity('ipapi', status, 'text/html', body, account).authenticated, false);
  }
  assert.equal(httpAccountIdentity('cloudflare', 200, 'application/json', '{"success":false}', email).authenticated, false);
});

test('HTTP reads use private state without starting Chrome; reject redirects and dispose on failure', async () => {
  let disposed = 0, reads = 0;
  const dependencies = {
    readSecret: async () => ({ secret: JSON.stringify({ cookies: [], origins: [] }) }),
    createContext: async () => ({ dispose: async () => { disposed++; } }),
    readResponse: async (_, options) => {
      reads++;
      assert.equal(options.maxRedirects, 0);
      assert.deepEqual(options.readBodyForStatuses, [200]);
      assert.equal(options.url, 'https://ipapi.is/app/home');
      return { status: 200, contentType: 'text/html', body: Buffer.from(html) };
    },
  };
  assert.equal((await readHttpAccount('ipapi', email, dependencies)).authenticated, true);
  assert.equal(disposed, 1);
  assert.equal(reads, 1);
  const failed = await readHttpAccount('ipapi', email, { ...dependencies, readResponse: async () => { throw new Error('private cookie value'); } });
  assert.equal(failed.state, 'session_unavailable');
  assert.equal(JSON.stringify(failed).includes('private cookie value'), false);
  assert.equal(disposed, 2);
});

test('AbuseIPDB HTTP identity ignores feedback/change-password forms and exposes privacy booleans only', () => {
  const form = `<form action="/account/update-basics"><input name="email" value="${email}">
    <input name="public" type="checkbox"><input name="domain-visibility" type="checkbox"></form>`;
  const body = `${form}<form action="/logout"></form><input name="email" value="feedback@example.test"><input type="password">`;
  const observed = httpAccountIdentity('abuseipdb', 200, 'text/html', body, email);
  assert.equal(observed.authenticated, true);
  assert.equal(observed.publicProfile, false);
  assert.equal(observed.publicDomain, false);
  assert.equal(observed.emailVerificationPending, false);
  assert.equal(JSON.stringify(observed).includes(email), false);
  const pending = httpAccountIdentity('abuseipdb', 200, 'text/html', body.replace('name="public"', 'checked name="public"') +
    '<form action="/account/resend-email-verification"></form>', email);
  assert.equal(pending.publicProfile, true);
  assert.equal(pending.emailVerificationPending, true);
  for (const invalid of [body.replace(email, 'other@example.test'), body + form, `<script>${body}</script>`,
    body.replace('/logout', '/login'), '<form action="/login"><input name="email" value="fixture@example.test"></form>']) {
    assert.equal(httpAccountIdentity('abuseipdb', 200, 'text/html', invalid, email).authenticated, false);
  }
  assert.equal(httpAccountIdentity('abuseipdb', 302, 'text/html', body, email).authenticated, false);
});

test('hidden forms and data attributes cannot establish identity or privacy settings', () => {
  const abuse = `<form action="/account/update-basics"><input name="email" value="${email}">
    <input type="checkbox" name="public" title=" checked "></form><form action="/logout"></form>`;
  for (const [provider, proof] of [['ipapi', html], ['abuseipdb', abuse]]) {
    for (const hidden of [`<template>${proof}</template>`, `<div hidden>${proof}</div>`, `<section inert>${proof}</section>`,
      `<div style="display: none">${proof}</div>`, proof.replace(/ (href|action)=/g, ' data-$1=')]) {
      assert.equal(httpAccountIdentity(provider, 200, 'text/html', '<p>Loading</p>' + hidden, email).authenticated, false);
    }
  }
  const result = httpAccountIdentity('abuseipdb', 200, 'text/html', abuse + '<template><form action="/account/resend-email-verification"></form></template>', email);
  assert.equal(result.publicProfile, false);
  assert.equal(result.emailVerificationPending, false);
  assert.equal(httpAccountIdentity('ipapi', 200, 'text/html', html.replace('name="email"', 'type="hidden" name="email"'), email).authenticated, false);
});
