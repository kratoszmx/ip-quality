import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';
import { Agent } from 'node:https';
import { chromium } from 'playwright-core';
import { connectOrLaunchChromeOverCDP, ensurePrivateDirectoryStrict, verifyChromeProfileBinding, withLoopbackOperationLease } from '@codex-mcp/shared-browser-session';
import { inspectPrivateSecretFile, readPrivateSecretFile, writePrivateSecretFile } from '@codex-mcp/shared-secret-file';
import { requestHttpRead } from '@codex-mcp/shared-http-read';
import { providerConfig, accountUrl, accountPagePath, assertAccountOrigin, redactAccountText, classifyAccountPage, validApiKey, ipapiKeyAccepted } from './policy.mjs';
import { submitReviewedSignup } from './signup.mjs';

export const ROOT = path.dirname(fileURLToPath(import.meta.url));
export const SECRETS = path.resolve(ROOT, '../../secrets');
const secret = (provider, name) => path.join(SECRETS, 'accounts', providerConfig(provider) && provider, name);
const keyFile = provider => path.join(SECRETS, provider === 'ipapi' ? 'ipapi' : 'cloudflare_token');
const keyPolicy = { minBytes: 8, maxBytes: 256, validate: validApiKey };

export function proxyServer() {
  const value = process.env.PROVIDER_ACCOUNTS_PROXY || process.env.HTTPS_PROXY || process.env.https_proxy;
  if (!value) return undefined;
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.pathname !== '/' || url.search || url.hash) throw new Error('Invalid credential-free proxy URL.');
  return value;
}

export async function withSession(provider, operation, { foreground = false } = {}) {
  const config = providerConfig(provider);
  return withLoopbackOperationLease({ port: config.port + 100 }, async () => {
    const profileDir = path.join(ROOT, '.state', provider);
    await ensurePrivateDirectoryStrict(profileDir);
    const session = await connectOrLaunchChromeOverCDP(chromium, {
      profileDir, cdpPort: config.port, proxyServer: proxyServer(), startUrl: 'about:blank',
      background: !foreground, hidden: !foreground, detached: true, unref: true,
      preserveContextSettings: true, timeoutMs: 20_000, killLaunchedProcessOnClose: false,
    });
    try {
      await verifyChromeProfileBinding(session.browser, profileDir);
      if (session.browser.contexts().length !== 1 || session.context.pages().length !== 1) throw new Error('Expected one dedicated account page.');
      if (foreground) await session.page.bringToFront();
      return await operation(session.page);
    } finally { await session.close(); }
  });
}

export async function privateAccount(provider) {
  const value = await readPrivateSecretFile(secret(provider, 'credentials.json'), { maxBytes: 4096 });
  const account = JSON.parse(value.secret);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(account.email) || typeof account.password !== 'string' || account.password.length < 20) throw new Error('Invalid saved account.');
  return account;
}

async function snapshot(provider, page, submitted = false) {
  assertAccountOrigin(provider, page.url());
  const view = await page.evaluate(() => {
    const visible = node => !!(node.getClientRects().length && getComputedStyle(node).visibility !== 'hidden');
    const text = document.body.innerText;
    const response = document.querySelector('input[name="cf_challenge_response"], input[name="cf-turnstile-response"]');
    const challenge = response ? !response.value : /verify you are human|let us know you are human|checking your browser/i.test(text);
    const controls = [...document.querySelectorAll('input,select,button')].filter(visible).slice(0, 200).map(e => ({
      tag: e.tagName.toLowerCase(), type: e.type, name: e.name.slice(0, 80),
      ...(e.tagName === 'BUTTON' ? { label: e.innerText.trim().slice(0, 80) } : {}),
    }));
    return { text, controls, hasPassword: controls.some(e => e.type === 'password'), challenge };
  });
  const account = await privateAccount(provider).catch(() => null);
  return { provider, page: accountPagePath(provider, page.url()),
    state: classifyAccountPage({ ...view, submitted }),
    text: /two.factor|2FA|recovery codes|authenticator|secret key/i.test(view.text)
      ? '[security values omitted; inspect value-free controls]' : redactAccountText(view.text, account ? [account.email, account.password] : []),
    controls: view.controls.map(e => ({ ...e, ...(e.label ? { label: redactAccountText(e.label) } : {}) })),
  };
}

export async function accountStatus(provider) {
  providerConfig(provider);
  const [account, key, attempt] = await Promise.all([
    inspectPrivateSecretFile(secret(provider, 'credentials.json')),
    inspectPrivateSecretFile(keyFile(provider), keyPolicy),
    inspectPrivateSecretFile(secret(provider, 'registration-attempt.json')),
  ]);
  return { provider, savedAccount: account.usable, apiKeyConfigured: key.usable, registrationAttempted: attempt.exists, liveAuthenticationChecked: false };
}

export async function openAccount(provider, surface) {
  const url = accountUrl(provider, surface);
  return withSession(provider, async page => {
    const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20_000 });
    if (response && response.status() >= 400) return { provider, state: 'access_unavailable', httpStatus: response.status() };
    await page.locator('body').waitFor({ timeout: 10_000 });
    return snapshot(provider, page);
  }, { foreground: true });
}

export async function readAccount(provider) {
  return withSession(provider, page => snapshot(provider, page));
}

// Credentials are persisted before the sole submission. A durable attempt
// receipt prevents accidental duplicate signups after a timeout or restart.
export async function createFreeAccount(provider, country, confirmation) {
  if (confirmation !== 'CREATE_FREE_ACCOUNT') throw new Error('Explicit free-account confirmation required.');
  const config = providerConfig(provider);
  if (provider === 'ipapi' && !['Hong Kong', 'China'].includes(country)) throw new Error('The account country must be confirmed.');
  return withSession(provider, async page => {
    assertAccountOrigin(provider, page.url());
    if (new URL(page.url()).pathname !== config.signup) throw new Error('Open the reviewed signup page first.');
    const current = await snapshot(provider, page);
    if (current.state === 'human_verification_required') return current;
    const attempt = await inspectPrivateSecretFile(secret(provider, 'registration-attempt.json'));
    if (attempt.exists) throw new Error('Registration was already attempted; inspect the account or use its saved login.');
    if (provider === 'ipapi' && !current.text.includes('1,000 free daily API requests')) throw new Error('Free offer could not be verified.');
    let account = await privateAccount(provider).catch(() => null);
    if (!account) {
      const identity = await readPrivateSecretFile(path.join(SECRETS, 'accounts', 'registration-email'), { minBytes: 3, maxBytes: 320, validate: value => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) });
      account = { email: identity.secret, password: 'Aa1!' + randomBytes(30).toString('base64url') };
      const saved = await writePrivateSecretFile(secret(provider, 'credentials.json'), JSON.stringify(account));
      if (saved.conflict) throw new Error('Account file changed concurrently.');
    }
    await submitReviewedSignup(page, provider, account, country, async () => {
      const saved = await writePrivateSecretFile(secret(provider, 'registration-attempt.json'), JSON.stringify({ attemptedAt: new Date().toISOString(), freeOnly: true }));
      if (saved.conflict || !saved.changed) throw new Error('Registration attempt already reserved.');
    });
    return snapshot(provider, page, true);
  });
}

export async function importIpapiKey(confirmation) {
  if (confirmation !== 'IMPORT_FREE_API_KEY') throw new Error('Explicit key-import confirmation required.');
  return withSession('ipapi', async page => {
    const current = await snapshot('ipapi', page);
    if (current.state !== 'authenticated') throw new Error('No verified ipapi account page.');
    // Extract only explicitly labelled key controls. Never guess from arbitrary
    // page strings such as CSRF tokens, account ids or passwords.
    const candidates = await page.locator('input[name*="api_key"], input[id*="api_key"], input[name="key"], input[id="api-key"]').evaluateAll(elements => elements.filter(e => e.getClientRects().length).map(e => e.value));
    const keys = [...new Set(candidates.filter(validApiKey))];
    if (keys.length !== 1) throw new Error('Expected one visible labelled API key.');
    const url = new URL('https://api.ipapi.is/');
    url.searchParams.set('q', '1.1.1.1'); url.searchParams.set('key', keys[0]);
    const proxy = proxyServer();
    const agent = new Agent({ proxyEnv: proxy ? { https_proxy: proxy } : {} });
    try {
      const response = await requestHttpRead({ url: url.href, agent, maxBytes: 131072, timeoutMs: 15_000, maxRedirects: 0 });
      let body; try { body = JSON.parse(response.body.toString('utf8')); } catch { throw new Error('API returned invalid JSON.'); }
      if (!ipapiKeyAccepted(response.status, body, '1.1.1.1')) return { provider: 'ipapi', imported: false, state: 'key_unverified', httpStatus: response.status };
      const written = await writePrivateSecretFile(keyFile('ipapi'), keys[0], keyPolicy);
      if (written.conflict) throw new Error('A different local API key already exists.');
      return { provider: 'ipapi', imported: true, fullApiVerified: true, lookupsUsed: 1 };
    } finally { agent.destroy(); }
  });
}
