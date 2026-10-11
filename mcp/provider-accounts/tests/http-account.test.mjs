import assert from 'node:assert/strict';
import test from 'node:test';
import { httpAccountIdentity, readHttpAccount } from '../http-account.mjs';

const email = 'fixture@example.test';
const html = `<input name="email" value="${email}"><input name="key" value="private"><a href="/app/logout">Logout</a>`;
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
