import { fileURLToPath } from 'node:url';
import { request } from 'playwright-core';
import { readPrivateSecretFile } from '@codex-mcp/shared-secret-file';
import { requestBinaryWithBrowserContext } from '@codex-mcp/shared-browser-session';
import { providerConfig, accountNetworkOptions } from './policy.mjs';
import { cloudflareIdentity } from './cloudflare-policy.mjs';

export function httpStatePath(provider) {
  providerConfig(provider);
  return fileURLToPath(new URL(`./.state/${provider}-http.json`, import.meta.url));
}

export function httpAccountIdentity(provider, status, contentType, body, expectedEmail) {
  providerConfig(provider);
  const unavailable = { provider, backend: 'http', authenticated: false,
    state: status === 429 ? 'rate_limited' : [301, 302, 303, 307, 308, 401].includes(status) ? 'login_required' : 'unconfirmed', httpStatus: status };
  if (status !== 200) return unavailable;
  if (provider === 'cloudflare') {
    let value;
    if (/^application\/json\b/i.test(contentType || '')) { try { value = JSON.parse(body); } catch { /* unconfirmed */ } }
    const identity = cloudflareIdentity(status, value, expectedEmail);
    return { ...unavailable, ...identity, state: identity.authenticated ? 'authenticated' : 'login_required' };
  }
  if (!/^text\/html\b/i.test(contentType || '') || typeof expectedEmail !== 'string' || !expectedEmail) return unavailable;
  // Only server-rendered, labelled account inputs prove the saved identity.
  // Scripts/comments and password/login forms cannot supply that evidence.
  const html = body.replace(/<!--[\s\S]*?-->|<script\b[^>]*>[\s\S]*?<\/script\s*>/gi, '');
  if (/<input\b[^>]*\btype\s*=\s*(?:"password"|'password'|password(?=[\s/>]))/i.test(html)) return { ...unavailable, state: 'login_required' };
  const inputs = [...html.matchAll(/<input\b[^>]*>/gi)].map(([tag]) => Object.fromEntries(
    [...tag.matchAll(/([\w-]+)\s*=\s*(["'])(.*?)\2/g)].map(([, key, , value]) => [key.toLowerCase(), value])));
  const emails = inputs.filter(input => input.name === 'email');
  const authenticated = emails.length === 1 && emails[0].value === expectedEmail &&
    inputs.filter(input => input.name === 'key').length === 1 &&
    !inputs.some(input => input.type?.toLowerCase() === 'password') &&
    /<a\b[^>]*\bhref=["']\/app\/logout["']/i.test(html);
  return { ...unavailable, authenticated, state: authenticated ? 'authenticated' : 'login_required' };
}

export async function readHttpAccount(provider, expectedEmail, dependencies = {}) {
  const config = providerConfig(provider);
  const readSecret = dependencies.readSecret || readPrivateSecretFile;
  const createContext = dependencies.createContext || (options => request.newContext(options));
  let context;
  try {
    const stored = await readSecret(httpStatePath(provider), { minBytes: 2, maxBytes: 2_097_152 });
    const storageState = JSON.parse(stored.secret);
    if (!Array.isArray(storageState.cookies) || !Array.isArray(storageState.origins)) throw new Error('Invalid saved state.');
    const proxy = accountNetworkOptions().proxyServer;
    context = await createContext({ storageState, ...(proxy ? { proxy: { server: proxy } } : {}) });
    const read = dependencies.readResponse || requestBinaryWithBrowserContext;
    const response = await read({ request: context }, {
      url: provider === 'cloudflare' ? `${config.origin}/api/v4/user` : `${config.origin}${config.dashboard}`,
      headers: { 'Cache-Control': 'no-cache' }, timeoutMs: 15000, maxRedirects: 0,
      maxResponseBytes: 524288, readBodyForStatuses: [200],
    });
    return httpAccountIdentity(provider, response.status, response.contentType, response.body.toString('utf8'), expectedEmail);
  } catch {
    return { provider, backend: 'http', authenticated: false, state: 'session_unavailable', nextStep: 'Restore the dedicated account login and refresh its private HTTP state.' };
  } finally { await context?.dispose().catch(() => {}); }
}
