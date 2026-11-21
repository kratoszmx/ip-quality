import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';
import { Agent } from 'node:https';
import { chromium } from 'playwright-core';
import { withLoopbackOperationLease } from '@myutils/browser-session';
import { releaseDedicatedChromePages, withDedicatedChrome } from '@myutils/web-text/dedicated-chrome';
import { sharedChromeRuntime } from '@myutils/web-text/shared-chrome';
import { inspectPrivateSecretFile, readPrivateSecretFile, writePrivateSecretFile } from '@myutils/secret-file';
import { requestHttpRead } from '@myutils/http-read';
import { redactText } from '@myutils/redaction';
import { providerConfig, accountUrl, accountPagePath, accountNetworkOptions, assertAccountOrigin, classifyAccountPage, ipapiDashboardAccepted, validApiKey, ipapiKeyAccepted } from './policy.mjs';
import { submitReviewedSignup } from './signup.mjs';
import { readHttpAccount } from './http-account.mjs';
import { prepareBrowserVerification } from '../common/verification.mjs';

export const ROOT = path.dirname(fileURLToPath(import.meta.url));
export const SECRETS = path.resolve(ROOT, '../../secrets');
const secret = (provider, name) => path.join(SECRETS, 'accounts', providerConfig(provider) && provider, name);
const keyFile = provider => path.join(SECRETS, provider === 'ipapi' ? 'ipapi' : 'cloudflare_token');
const keyPolicy = { minBytes: 8, maxBytes: 256, validate: validApiKey };
let keptProvider = null;

// Every account login lives in the shared Chrome profile (the text browser's
// saved profile); pages are tabs of the one dedicated Chrome on it. A call that
// opens a page keeps its hidden tab for the next step of the flow (`retain`),
// `current` continues on that tab, `own` reads in a tab of its own. `foreground`
// opens a window of the same Chrome for the owner.
export async function withSession(provider, operation, { foreground = false, page = 'retain' } = {}) {
  const config = providerConfig(provider);
  return withLoopbackOperationLease({ port: config.port + 100 }, async () => {
    if (page === 'current' && keptProvider !== provider) throw new Error('Open the provider page first.');
    const keeps = page === 'retain' && !foreground;
    if (keeps) keptProvider = null;
    const result = await withDedicatedChrome(sharedChromeRuntime({ chromium }),
      { locale: 'en-US', window: foreground ? 'shown' : 'hidden', deadline: Date.now() + 60_000, page },
      (_session, tab) => operation(tab));
    if (keeps) keptProvider = provider;
    return result;
  });
}

export async function closeAccountBrowsers() {
  keptProvider = null;
  await releaseDedicatedChromePages();
  return { released: true };
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
    const hasPassword = controls.some(e => e.type === 'password');
    // ipapi's logout is an icon, with no visible "Sign out" text. Bind its
    // server-rendered dashboard to the saved identity before importing a key.
    const account = { url: location.href, email: document.querySelector('input[name="email"]')?.value,
      logoutUrl: document.querySelector('a[href="/app/logout"]')?.href,
      keyCount: [...document.querySelectorAll('input[name="key"]')].filter(visible).length, hasPassword };
    return { text, controls, hasPassword, challenge, account };
  });
  const account = await privateAccount(provider).catch(() => null);
  return { provider, page: accountPagePath(provider, page.url()),
    state: classifyAccountPage({ ...view, submitted, termsRequired: provider === 'ipapi' && new URL(page.url()).pathname === '/app/accept-terms',
      allowTextAuthentication: provider !== 'ipapi', authenticatedAccount: provider === 'ipapi' && ipapiDashboardAccepted(view.account, account?.email) }),
    text: /two.factor|2FA|recovery codes|authenticator|secret key/i.test(view.text)
      ? '[security values omitted; inspect value-free controls]' : redactText(view.text, { secrets: account ? [account.email, account.password] : [] }).slice(0, 6000),
    controls: view.controls.map(e => ({ ...e, ...(e.label ? { label: redactText(e.label).slice(0, 6000) } : {}) })),
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

export async function openAccount(provider, surface, visible = false) {
  const url = accountUrl(provider, surface);
  return withSession(provider, async page => {
    const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20_000 });
    const verification = await prepareBrowserVerification(page, providerConfig(provider).origin);
    if (response && response.status() >= 400 && (!verification.encountered || verification.pending))
      return { provider, state: verification.pending ? 'human_verification_required' : 'access_unavailable', httpStatus: response.status(), verification };
    await page.locator('body').waitFor({ timeout: 10_000 });
    if (provider === 'cloudflare') await page.waitForFunction(() =>
      !!document.querySelector('input[type="password"],a[href*="logout"]') ||
      /verify you are human|let us know you are human|checking your browser/i.test(document.body?.innerText || ''),
    undefined, { timeout: 10_000, polling: 100 }).catch(() => {});
    return { ...await snapshot(provider, page), verification };
  }, { foreground: visible });
}

export async function readAccount(provider, mode = 'http') {
  if (mode === 'browser') return withSession(provider, async page => {
    await page.goto(accountUrl(provider, 'dashboard'), { waitUntil: 'domcontentloaded', timeout: 20000 });
    return snapshot(provider, page);
  }, { page: 'own' });
  if (mode !== 'http') throw new Error('Unknown read mode.');
  return readHttpAccount(provider, (await privateAccount(provider)).email);
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
    await prepareBrowserVerification(page, config.origin);
    const current = await snapshot(provider, page);
    if (['human_verification_required', 'automated_browser_blocked'].includes(current.state)) return current;
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
  }, { page: 'current' });
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
    const proxy = accountNetworkOptions().proxyServer;
    const agent = new Agent({ proxyEnv: proxy ? { https_proxy: proxy } : {} });
    try {
      const response = await requestHttpRead({ url: url.href, agent, maxBytes: 131072, timeoutMs: 15_000, maxRedirects: 0 });
      let body; try { body = JSON.parse(response.body.toString('utf8')); } catch { throw new Error('API returned invalid JSON.'); }
      if (!ipapiKeyAccepted(response.status, body, '1.1.1.1')) return { provider: 'ipapi', imported: false, state: 'key_unverified', httpStatus: response.status };
      const written = await writePrivateSecretFile(keyFile('ipapi'), keys[0], keyPolicy);
      if (written.conflict) throw new Error('A different local API key already exists.');
      return { provider: 'ipapi', imported: true, fullApiVerified: true, lookupsUsed: 1 };
    } finally { agent.destroy(); }
  }, { page: 'current' });
}
