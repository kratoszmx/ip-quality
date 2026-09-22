import assert from 'node:assert/strict';
import test from 'node:test';
import { cloudflareApiUsable, cloudflareIdentity, intelReadPolicy, usableBeforeMfa } from '../cloudflare-policy.mjs';
const accountId = 'a'.repeat(32), permissionId = 'b'.repeat(32);
const payload = () => ({ name: 'IPQuality Intel Read', policies: [{ effect: 'allow', permission_groups: [{ id: permissionId }], resources: { [`com.cloudflare.api.account.${accountId}`]: '*' } }], condition: {}, not_before: null, expires_on: null });

test('Intel token permits exactly one read permission on the configured account', () => {
  assert.equal(intelReadPolicy(payload(), accountId, permissionId), true);
  for (const change of [p => p.policies.push(p.policies[0]), p => p.policies[0].permission_groups.push({ id: 'c'.repeat(32) }), p => { p.policies[0].resources = { 'com.cloudflare.api.account.*': '*' }; }, p => { p.policies[0].effect = 'deny'; }, p => { p.name = 'Other token'; }, p => { p.policies[0].permission_groups[0].id = 'c'.repeat(32); }]) {
    const value = payload(); change(value); assert.equal(intelReadPolicy(value, accountId, permissionId), false);
  }
});

test('account authentication requires current server success and the saved identity', () => {
  const body = { success: true, result: { email: 'fixture@example.invalid', suspended: false, email_verified: true, two_factor_authentication_enabled: false } };
  assert.deepEqual(cloudflareIdentity(200, body, 'fixture@example.invalid'), { authenticated: true, emailVerified: true, twoFactorEnabled: false, totpConfigured: false });
  assert.equal(cloudflareIdentity(403, body, 'fixture@example.invalid').authenticated, false);
  assert.equal(cloudflareIdentity(200, body, 'different@example.invalid').authenticated, false);
});

test('free API proof needs the exact target and usable context, not merely HTTP 200', () => {
  const body = { success: true, result: [{ ip: '1.1.1.1', belongs_to_ref: { value: 'AS13335' }, risk_types: [] }] };
  assert.equal(cloudflareApiUsable(200, body, '1.1.1.1'), true);
  for (const status of [301, 401, 403, 429, 500]) assert.equal(cloudflareApiUsable(status, body, '1.1.1.1'), false);
  assert.equal(cloudflareApiUsable(200, body, '8.8.8.8'), false);
  assert.equal(cloudflareApiUsable(200, { success: true, result: [] }, '1.1.1.1'), false);
  assert.equal(cloudflareApiUsable(200, { success: true, result: [{ ip: '1.1.1.1' }] }, '1.1.1.1'), false);
  const liveShape = { success: true, result: [{ ip: '1.1.1.1', belongs_to_ref: { value: 13335 }, threat_summary: null }] };
  assert.equal(cloudflareApiUsable(200, liveShape, '1.1.1.1'), true);
  for (const value of [-1, 1.5, 4294967296]) assert.equal(cloudflareApiUsable(200, { success: true, result: [{ ...liveShape.result[0], belongs_to_ref: { value } }] }, '1.1.1.1'), false);
});

test('2FA needs fresh successful API evidence bound to the same token and account', () => {
  const now = Date.parse('2026-09-22T00:00:00Z');
  const proof = { provider: 'cloudflare', usable: true, checkedAt: new Date(now - 1000).toISOString(), keyFingerprint: 'fixture', accountId };
  assert.equal(usableBeforeMfa(proof, 'fixture', accountId, now), true);
  for (const changed of [{ usable: false }, { keyFingerprint: 'different' }, { accountId: 'c'.repeat(32) }, { checkedAt: new Date(now + 1).toISOString() }, { checkedAt: new Date(now - 1800001).toISOString() }]) assert.equal(usableBeforeMfa({ ...proof, ...changed }, 'fixture', accountId, now), false);
});
