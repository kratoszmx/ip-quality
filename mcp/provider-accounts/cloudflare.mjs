import path from 'node:path';
import { Agent } from 'node:https';
import { requestHttpRead } from '@codex-mcp/shared-http-read';
import { inspectPrivateSecretFile, readPrivateSecretFile, writePrivateSecretFile } from '@codex-mcp/shared-secret-file';
import { withLoopbackOperationLease, requestBinaryWithBrowserContext } from '@codex-mcp/shared-browser-session';
import { SECRETS, withSession, privateAccount } from './accounts.mjs';
import { accountNetworkOptions, assertAccountOrigin, validApiKey } from './policy.mjs';
import { cloudflareIdentity, cloudflareApiUsable, intelReadPolicy } from './cloudflare-policy.mjs';

const ORIGIN = 'https://dash.cloudflare.com';
export const keyPath = path.join(SECRETS, 'cloudflare_token');
export const accountPath = path.join(SECRETS, 'cloudflare_account_id');
export const statePath = name => path.join(SECRETS, 'accounts/cloudflare', name);
export const keyPolicy = { minBytes: 8, maxBytes: 256, validate: validApiKey };
export const accountPolicy = { minBytes: 32, maxBytes: 32, validate: value => /^[a-f0-9]{32}$/.test(value) };

export async function identityOnPage(page) {
  assertAccountOrigin('cloudflare', page.url());
  const account = await privateAccount('cloudflare');
  const response = await requestBinaryWithBrowserContext(page.context(), {
    url: `${ORIGIN}/api/v4/user`, headers: { 'Cache-Control': 'no-cache', Accept: 'application/json' },
    timeoutMs: 15000, maxRedirects: 0, maxResponseBytes: 131072, readBodyForStatuses: [200],
  });
  let body;
  if (/^application\/json\b/i.test(response.contentType || '')) { try { body = JSON.parse(response.body.toString('utf8')); } catch { /* unconfirmed */ } }
  return cloudflareIdentity(response.status, body, account.email);
}

export async function checkCloudflareAccount() {
  return withSession('cloudflare', async page => ({ provider: 'cloudflare', ...await identityOnPage(page) }));
}

async function reviewedPolicy(page, accountId) {
  assertAccountOrigin('cloudflare', page.url());
  if (new URL(page.url()).pathname !== `/${accountId}/api-tokens/create`) throw new Error('Expected this account token review.');
  const identity = await identityOnPage(page);
  if (!identity.authenticated || !identity.emailVerified) throw new Error('A verified account is required.');
  const catalog = await page.evaluate(async accountId => {
    const response = await fetch(`/api/v4/accounts/${accountId}/tokens/permission_groups`, { credentials: 'same-origin', cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(10000) });
    return { status: response.status, body: await response.json() };
  }, accountId);
  const groups = catalog.body?.result?.filter(group => group.name === 'Intel Read');
  if (catalog.status !== 200 || catalog.body.success !== true || !Array.isArray(groups) || groups.length !== 1) throw new Error('Intel Read permission is unavailable.');
  const payload = JSON.parse(await page.locator('pre:visible').innerText({ timeout: 5000 }));
  if (!intelReadPolicy(payload, accountId, groups[0].id)) throw new Error('Expected one account-scoped Intel Read policy.');
  return { payload, permissionId: groups[0].id };
}

export async function prepareCloudflareToken() {
  return withSession('cloudflare', async page => {
    const accountId = (await readPrivateSecretFile(accountPath, accountPolicy)).secret;
    const existing = await inspectPrivateSecretFile(keyPath);
    const attempted = await inspectPrivateSecretFile(statePath('token-creation-attempt.json'));
    if (existing.exists || attempted.exists) throw new Error('Inspect the saved token or prior attempt before preparing another.');
    await page.goto(`${ORIGIN}/${accountId}/api-tokens/create`, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.getByRole('textbox', { name: 'Token name', exact: true }).fill('IPQuality Intel Read', { timeout: 10000 });
    await page.getByRole('button', { name: 'Start from scratch Build a custom permission policy', exact: true }).click({ timeout: 5000 });
    await page.getByRole('textbox', { name: 'Search for permission groups...', exact: true }).fill('Intel');
    const row = page.locator('li').filter({ has: page.getByText('Intel', { exact: true }) });
    if (await row.count() !== 1 || await page.locator('[role="checkbox"][aria-checked="true"]').count() !== 0) throw new Error('Permission selection changed.');
    await row.locator('[role="checkbox"][aria-label="Read"]').click({ timeout: 5000 });
    await page.getByRole('button', { name: 'Review token', exact: true }).click({ timeout: 5000 });
    await page.locator('button').filter({ hasText: /^JSON Payload$/ }).click({ timeout: 5000 });
    await reviewedPolicy(page, accountId);
    return { provider: 'cloudflare', prepared: true, name: 'IPQuality Intel Read', permission: 'Intel Read', resource: 'configured account only', expires: 'no expiration', submitted: false };
  });
}

export async function createCloudflareToken(confirmation) {
  if (confirmation !== 'CREATE_INTEL_READ_TOKEN') throw new Error('Explicit token creation confirmation required.');
  return withSession('cloudflare', async page => {
    const accountId = (await readPrivateSecretFile(accountPath, accountPolicy)).secret;
    if ((await inspectPrivateSecretFile(keyPath)).exists) throw new Error('A local token already exists.');
    const { permissionId } = await reviewedPolicy(page, accountId);
    const button = page.getByRole('button', { name: 'Create token', exact: true });
    if (await button.count() !== 1 || !await button.isEnabled()) throw new Error('Token creation is not ready.');
    const endpoint = `${ORIGIN}/api/v4/accounts/${accountId}/tokens`;
    const guard = async route => {
      let payload; try { payload = route.request().postDataJSON(); } catch { /* rejected below */ }
      if (route.request().method() === 'POST' && intelReadPolicy(payload, accountId, permissionId)) await route.continue();
      else await route.abort('blockedbyclient');
    };
    const receipt = await writePrivateSecretFile(statePath('token-creation-attempt.json'), JSON.stringify({ attemptedAt: new Date().toISOString(), permission: 'Intel Read' }));
    if (receipt.conflict || !receipt.changed) throw new Error('Token creation was already attempted.');
    await page.route(endpoint, guard);
    try {
      const pending = page.waitForResponse(response => response.url() === endpoint && response.request().method() === 'POST', { timeout: 15000 }).catch(() => null);
      await button.click({ timeout: 10000 }).catch(() => {});
      const response = await pending;
      if (!response || response.status() !== 200) return { provider: 'cloudflare', state: 'token_creation_unconfirmed', created: false };
      const bytes = await response.body();
      if (bytes.length > 131072) throw new Error('Unexpected token response size.');
      const body = JSON.parse(bytes.toString('utf8'));
      if (body.success !== true || !validApiKey(body.result?.value) || !intelReadPolicy(body.result, accountId, permissionId)) throw new Error('Token response did not match the reviewed policy.');
      const saved = await writePrivateSecretFile(keyPath, body.result.value, keyPolicy);
      if (saved.conflict) throw new Error('The local token changed concurrently.');
      return { provider: 'cloudflare', created: true, saved: true, permission: 'Intel Read', apiUsabilityVerified: false };
    } finally { await page.unroute(endpoint, guard); }
  });
}

export async function verifyCloudflareApi(confirmation) {
  if (confirmation !== 'VERIFY_FREE_API') throw new Error('Explicit free API lookup confirmation required.');
  return withLoopbackOperationLease({ port: 19604 }, async () => {
    const key = await readPrivateSecretFile(keyPath, keyPolicy);
    const accountId = (await readPrivateSecretFile(accountPath, accountPolicy)).secret;
    const proxy = accountNetworkOptions().proxyServer;
    const agent = new Agent({ proxyEnv: proxy ? { https_proxy: proxy } : {} });
    try {
      const response = await requestHttpRead({ url: `https://api.cloudflare.com/client/v4/accounts/${accountId}/intel/ip?ipv4=1.1.1.1`, headers: { Authorization: `Bearer ${key.secret}`, Accept: 'application/json' }, agent, maxBytes: 131072, timeoutMs: 15000, maxRedirects: 0 });
      let body;
      if (/^application\/json\b/i.test(response.contentType || '')) { try { body = JSON.parse(response.body.toString('utf8')); } catch { /* unknown */ } }
      const usable = cloudflareApiUsable(response.status, body, '1.1.1.1');
      const proof = { provider: 'cloudflare', usable, checkedAt: new Date().toISOString(), keyFingerprint: key.fingerprint, accountId };
      const previous = await inspectPrivateSecretFile(statePath('availability.json'));
      const saved = await writePrivateSecretFile(statePath('availability.json'), JSON.stringify(proof), { replace: true, ...(previous.exists ? { expectedFingerprint: previous.fingerprint } : {}) });
      if (saved.conflict) throw new Error('Availability evidence changed concurrently.');
      return { provider: 'cloudflare', usable, httpStatus: response.status, lookupsUsed: 1,
        state: usable ? 'free_api_verified' : 'api_unavailable_or_incomplete',
        ...(usable ? { networkContext: true, threatCategories: body.result[0].risk_types?.length ?? null } : { errorCodes: Array.isArray(body?.errors) ? body.errors.map(error => error.code).filter(Number.isInteger).slice(0, 8) : [] }) };
    } finally { agent.destroy(); }
  });
}
