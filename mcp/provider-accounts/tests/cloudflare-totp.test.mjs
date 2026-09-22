import assert from 'node:assert/strict';
import test from 'node:test';
import { inspectTotpUri } from '@codex-mcp/shared-totp';
import { cloudflareTotpUri, submitCloudflareTotpForm, validateCloudflareRecoveryCodes } from '../cloudflare-totp.mjs';
const seed = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
const text = `Configure your authenticator app manually using code:\n${seed}\nNext`;
const account = { email: 'fixture@example.invalid', password: 'synthetic-password' };

test('text-only setup accepts one exact labelled seed and binds its issuer/account', () => {
  const uri = cloudflareTotpUri(text, account.email);
  assert.equal(inspectTotpUri(uri).digits, 6);
  assert.equal(new URL(uri).searchParams.get('issuer'), 'Cloudflare');
  assert.equal(decodeURIComponent(new URL(uri).pathname), '/Cloudflare:fixture@example.invalid');
  for (const invalid of [seed, text + '\n' + text, text.replace(seed, seed + 'A'), text.replace(seed, 'too-short')]) assert.throws(() => cloudflareTotpUri(invalid, account.email));
});

test('foreign or changed TOTP forms never read a generated code or submit credentials', async () => {
  const uri = cloudflareTotpUri(text, account.email);
  await assert.rejects(submitCloudflareTotpForm({ url: () => 'https://foreign.invalid/profile/access-management/authentication/setup' }, account, uri, async () => assert.fail('reserved')));
  const form = { filter() { return this; }, count: async () => 1, getAttribute: async () => '/changed' };
  await assert.rejects(submitCloudflareTotpForm({ url: () => 'https://dash.cloudflare.com/profile/access-management/authentication/setup', locator: () => form }, account, uri, async () => assert.fail('reserved')));
});

test('an existing enrollment reservation stops before filling or submitting', async () => {
  const uri = cloudflareTotpUri(text, account.email);
  const form = { filter() { return this; }, count: async () => 1, getAttribute: async () => null,
    getByRole: () => ({ count: async () => 1, isEnabled: async () => true, click: async () => assert.fail('submitted') }),
    locator: () => ({ fill: async () => assert.fail('filled') }),
  };
  await assert.rejects(submitCloudflareTotpForm({ url: () => 'https://dash.cloudflare.com/profile/access-management/authentication/setup', locator: () => form }, account, uri, async () => { throw new Error('already reserved'); }));
});

test('initial recovery storage requires exactly eight distinct codes with the observed format', () => {
  const codes = Array.from({ length: 8 }, (_, i) => String(100000000 + i));
  assert.equal(validateCloudflareRecoveryCodes(codes), true);
  for (const invalid of [codes.slice(1), [...codes, '100000009'], [...codes.slice(1), codes[1]], ['1234-5678', ...codes.slice(1)]]) assert.equal(validateCloudflareRecoveryCodes(invalid), false);
});
