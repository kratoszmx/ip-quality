import { saveStorageStateSafely, requestBinaryWithBrowserContext } from '@myutils/browser-session';
import { unlink } from 'node:fs/promises';
import { withSession, privateAccount } from './accounts.mjs';
import { providerConfig, accountUrl, assertAccountOrigin } from './policy.mjs';
import { httpStatePath, pendingLoginPath, httpAccountIdentity, readHttpAccount } from './http-account.mjs';

const loginForms = Object.freeze({
  cloudflare: { path: '/login', password: 'password', button: 'Sign in' },
  abuseipdb: { path: '/login', password: 'password', button: 'Login' },
});

export function loginFailureState({ challenge, text, hasPassword, path }) {
  if (path === '/app/accept-terms') return 'terms_acceptance_required';
  if (challenge) return 'human_verification_required';
  if (/invalid (?:email|password|credentials)|incorrect (?:email|password)|wrong password|login failed|could not sign in/i.test(text)) return 'credential_rejected';
  if (/verify (?:your )?email|activate your account|account is not activated/i.test(text)) return 'email_verification_required';
  if (/verification code|two.factor|authenticator/i.test(text) && !hasPassword) return 'secondary_verification_required';
  return 'login_unconfirmed';
}

async function failureOnPage(page) {
  return loginFailureState(await page.evaluate(() => ({
    challenge: [...document.querySelectorAll('input[name="cf_challenge_response"],input[name="cf-turnstile-response"]')].some(e => !e.value) ||
      /verify you are human|let us know you are human|checking your browser/i.test(document.body?.innerText || ''),
    text: (document.body?.innerText || '').slice(0, 20000),
    path: location.pathname,
    hasPassword: !!document.querySelector('input[type="password"]'),
  })));
}

export function acceptsLoginForm(provider, metadata) {
  const config = providerConfig(provider), form = loginForms[provider];
  if (!form) return false;
  try {
    const current = new URL(metadata.url), action = new URL(metadata.action || metadata.url, metadata.url);
    return !current.username && !current.password && !action.username && !action.password &&
      current.origin === config.origin && current.pathname === form.path && action.origin === config.origin &&
      action.pathname === form.path && metadata.method.toLowerCase() === 'post' && metadata.button === form.button &&
      metadata.fields.filter(name => name === 'email').length === 1 && metadata.fields.filter(name => name === form.password).length === 1;
  } catch { return false; }
}

export async function loginAccount(provider, confirmation) {
  if (confirmation !== 'USE_SAVED_ACCOUNT_CREDENTIALS') throw new Error('Saved login needs explicit task authorization.');
  const config = providerConfig(provider), policy = loginForms[provider];
  // The provider explicitly suspended the account for bot-controlled login.
  // Do not retry credentials in another browser or route to evade that decision.
  if (!policy) return { provider, state: 'manual_login_required', liveAuthenticationChecked: false,
    credentialsSubmitted: false, retryAutomatically: false,
    nextStep: 'Automated ipapi login is disabled after the provider bot_login suspension. Use the HTTP account read for existing state; account recovery requires provider support.' };
  const account = await privateAccount(provider);
  const existing = await readHttpAccount(provider, account.email);
  if (existing.authenticated) return { ...existing, credentialsSubmitted: false };
  return withSession(provider, async page => {
    const response = await page.goto(accountUrl(provider, 'login'), { waitUntil: 'domcontentloaded', timeout: 20000 });
    if (response?.status() >= 400) return { provider, authenticated: false, state: 'access_unavailable', httpStatus: response.status(), credentialsSubmitted: false };
    await page.waitForFunction(() => document.querySelector('input[type="password"]') || /verify you are human|let us know you are human/i.test(document.body?.innerText || ''), undefined, { timeout: 10000, polling: 100 }).catch(() => {});
    assertAccountOrigin(provider, page.url());
    const before = await failureOnPage(page);
    if (['human_verification_required', 'terms_acceptance_required', 'secondary_verification_required'].includes(before)) {
      return { provider, authenticated: false, state: before, credentialsSubmitted: false };
    }
    const form = page.locator('form').filter({ has: page.locator(`input[type="password"][name="${policy.password}"]`) });
    if (await form.count() !== 1) return { provider, authenticated: false, state: 'unrecognized_login_form', credentialsSubmitted: false };
    const metadata = await form.evaluate(f => ({ url: location.href, action: f.getAttribute('action'), method: f.method,
      fields: [...f.querySelectorAll('input')].map(e => e.name), button: f.querySelector('button[type="submit"]')?.textContent.trim() }));
    if (!acceptsLoginForm(provider, metadata)) throw new Error('Unreviewed account login form.');
    const email = form.locator('input[name="email"]'), password = form.locator(`input[name="${policy.password}"]`);
    let submitted = false;
    try {
      await email.fill(account.email, { timeout: 5000 }); await password.fill(account.password, { timeout: 5000 });
      submitted = true;
      await form.getByRole('button', { name: policy.button, exact: true }).click({ timeout: 10000 });
      await page.waitForLoadState('domcontentloaded', { timeout: 15000 }).catch(() => {});
      await page.waitForFunction(() => !document.querySelector('input[type="password"]') || /invalid|incorrect|verify you are human|captcha/i.test(document.body?.innerText || ''), undefined, { timeout: 8000, polling: 100 }).catch(() => {});
      assertAccountOrigin(provider, page.url());
      const probe = await requestBinaryWithBrowserContext(page.context(), {
        url: provider === 'cloudflare' ? `${config.origin}/api/v4/user` : `${config.origin}${config.dashboard}`,
        headers: { 'Cache-Control': 'no-cache' }, timeoutMs: 15000, maxRedirects: 0,
        maxResponseBytes: 524288, readBodyForStatuses: [200],
      });
      const identity = httpAccountIdentity(provider, probe.status, probe.contentType, probe.body.toString('utf8'), account.email);
      const failure = identity.authenticated ? null : await failureOnPage(page);
      if (identity.authenticated) {
        await saveStorageStateSafely(page.context(), httpStatePath(provider));
        await unlink(pendingLoginPath(provider)).catch(error => { if (error.code !== 'ENOENT') throw error; });
      } else if (['human_verification_required', 'terms_acceptance_required', 'secondary_verification_required'].includes(failure)) {
        // Pending cookies are isolated from verified HTTP state. They permit
        // later authorized review without claiming auth or retyping passwords.
        await saveStorageStateSafely(page.context(), pendingLoginPath(provider));
      }
      return { ...identity, credentialsSubmitted: true, retryAutomatically: false,
        ...(!identity.authenticated ? { state: failure, nextStep: 'Inspect the existing windowless page; verification or updated terms may still be required. Do not repeat the password submission.' } : {}) };
    } catch {
      return { provider, authenticated: false, state: 'login_unconfirmed', credentialsSubmitted: submitted, retryAutomatically: false };
    } finally { if (await password.count() === 1) await password.fill('', { timeout: 500 }).catch(() => {}); }
  });
}
