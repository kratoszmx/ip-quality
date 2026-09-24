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
