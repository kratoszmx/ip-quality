import { generateTotp, inspectTotpUri, isTotpUri } from '@codex-mcp/shared-totp';
import { inspectPrivateSecretFile, readPrivateSecretFile, writePrivateSecretFile } from '@codex-mcp/shared-secret-file';
import { withSession, privateAccount } from './accounts.mjs';
import { assertAccountOrigin } from './policy.mjs';
import { usableBeforeMfa } from './cloudflare-policy.mjs';
import { identityOnPage, statePath, keyPath, accountPath, keyPolicy, accountPolicy } from './cloudflare.mjs';

const SETUP_PATH = '/profile/access-management/authentication/setup';
const SECURITY_URL = 'https://dash.cloudflare.com/profile/access-management/authentication/two-factor';

export function cloudflareTotpUri(text, email) {
  if (typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('Invalid account identity.');
  const matches = [...text.matchAll(/Configure your authenticator app manually using code:\s*([A-Z2-7]{32})\s*(?=\n|$)/g)];
  if (matches.length !== 1) throw new Error('Expected one textual Cloudflare setup seed.');
  const uri = `otpauth://totp/${encodeURIComponent(`Cloudflare:${email}`)}?secret=${matches[0][1]}&issuer=Cloudflare&algorithm=SHA1&digits=6&period=30`;
  inspectTotpUri(uri);
  return uri;
}

export async function submitCloudflareTotpForm(page, account, uri, reserveAttempt) {
  assertAccountOrigin('cloudflare', page.url());
  if (new URL(page.url()).pathname !== SETUP_PATH) throw new Error('Expected Cloudflare TOTP setup.');
  const form = page.locator('form').filter({ has: page.locator('input[name="google_authenticator_code"]') });
  if (await form.count() !== 1 || await form.getAttribute('action') || await form.getAttribute('method')) throw new Error('Cloudflare setup form changed.');
  const next = form.getByRole('button', { name: 'Next', exact: true });
  if (await next.count() !== 1 || !await next.isEnabled()) throw new Error('TOTP setup is not ready.');
  await reserveAttempt();
  let totp = generateTotp(uri);
  if (totp.remainingMs < 5000) {
    await new Promise(resolve => setTimeout(resolve, totp.remainingMs + 100));
    totp = generateTotp(uri);
  }
  await form.locator('input[name="password"]').fill(account.password);
  await form.locator('input[name="google_authenticator_code"]').fill(totp.code);
  await next.click({ timeout: 10000 });
  await page.waitForFunction(initial => location.pathname !== initial || /recovery codes|incorrect|invalid/i.test(document.body?.innerText || ''), SETUP_PATH, { timeout: 15000 }).catch(() => {});
}

export async function enableCloudflareTotp(confirmation) {
  if (confirmation !== 'ENABLE_TOTP') throw new Error('Explicit 2FA setup confirmation required.');
  const key = await readPrivateSecretFile(keyPath, keyPolicy);
  const accountId = (await readPrivateSecretFile(accountPath, accountPolicy)).secret;
  const proof = JSON.parse((await readPrivateSecretFile(statePath('availability.json'))).secret);
  if (!usableBeforeMfa(proof, key.fingerprint, accountId)) throw new Error('Verify useful free API access before 2FA.');
  return withSession('cloudflare', async page => {
    const identity = await identityOnPage(page);
    if (!identity.authenticated || !identity.emailVerified) throw new Error('Expected the verified account.');
    if (identity.totpConfigured) return { provider: 'cloudflare', enabled: true, changed: false, recoverySaved: (await inspectPrivateSecretFile(statePath('recovery-codes.json'))).usable };
    if ((await inspectPrivateSecretFile(statePath('totp-enrollment-attempt.json'))).exists) throw new Error('Inspect the prior enrollment before any repeat.');
    if (new URL(page.url()).pathname !== SETUP_PATH) {
      await page.goto(SECURITY_URL, { waitUntil: 'domcontentloaded', timeout: 20000 });
      const heading = page.getByText('Mobile App Authentication', { exact: true });
      await heading.waitFor({ timeout: 10000 });
      const section = heading.locator('xpath=ancestor::*[.//button][1]');
      if (await section.getByRole('button', { name: 'Add', exact: true }).count() !== 1) throw new Error('Expected one mobile app enrollment control.');
      await section.getByRole('button', { name: 'Add', exact: true }).click({ timeout: 5000 });
    }
    await page.locator('input[name="google_authenticator_code"]').waitFor({ timeout: 10000 });
    if (!await page.getByText('Configure your authenticator app manually using code:', { exact: true }).isVisible()) {
      await page.getByRole('button', { name: 'Can’t scan the QR code? Follow alternative steps', exact: true }).click({ timeout: 5000 });
    }
    const account = await privateAccount('cloudflare');
    const uri = cloudflareTotpUri(await page.locator('body').innerText(), account.email);
    const saved = await writePrivateSecretFile(statePath('totp-uri'), uri, { maxBytes: 4096, validate: isTotpUri });
    if (saved.conflict) throw new Error('A different local authenticator seed exists.');
    await submitCloudflareTotpForm(page, account, uri, async () => {
      const reserved = await writePrivateSecretFile(statePath('totp-enrollment-attempt.json'), JSON.stringify({ attemptedAt: new Date().toISOString(), apiVerifiedAt: proof.checkedAt }));
      if (reserved.conflict || !reserved.changed) throw new Error('TOTP enrollment was already attempted.');
    });
    const after = await identityOnPage(page);
    return { provider: 'cloudflare', enabled: after.authenticated && after.twoFactorEnabled && after.totpConfigured,
      seedSaved: true, recoverySaved: (await inspectPrivateSecretFile(statePath('recovery-codes.json'))).usable,
      state: after.totpConfigured ? 'totp_enabled_recovery_pending' : 'enrollment_unconfirmed' };
  });
}

export function validateCloudflareRecoveryCodes(codes) {
  return Array.isArray(codes) && codes.length === 8 && new Set(codes).size === 8 &&
    codes.every(code => typeof code === 'string' && /^\d{9}$/.test(code));
}

export async function saveCloudflareRecoveryCodes(confirmation) {
  if (confirmation !== 'SAVE_RECOVERY_CODES') throw new Error('Explicit private recovery-code storage confirmation required.');
  return withSession('cloudflare', async page => {
    const identity = await identityOnPage(page);
    if (!identity.authenticated || !identity.twoFactorEnabled || !identity.totpConfigured) throw new Error('Expected the enabled Cloudflare authenticator.');
    const file = statePath('recovery-codes.json');
    const existing = await inspectPrivateSecretFile(file);
    if (existing.usable) {
      const saved = JSON.parse((await readPrivateSecretFile(file)).secret);
      if (!validateCloudflareRecoveryCodes(saved.codes)) throw new Error('Unexpected saved recovery data.');
      return { provider: 'cloudflare', saved: true, codeCount: saved.codes.length, changed: false };
    }
    if (new URL(page.url()).pathname !== '/profile/access-management/authentication/recovery-codes') throw new Error('Open the initial recovery page.');
    const password = page.locator('input[name="password"]');
    if (await password.count() === 1) {
      const form = page.locator('form').filter({ has: password });
      if (await form.count() !== 1 || await form.getAttribute('action') || await form.getAttribute('method') || await form.locator('input').count() !== 1) throw new Error('Recovery form changed.');
      const receipt = await writePrivateSecretFile(statePath('recovery-view-attempt.json'), JSON.stringify({ attemptedAt: new Date().toISOString() }));
      if (receipt.conflict || !receipt.changed) throw new Error('Inspect the previous recovery request before repeating it.');
      await password.fill((await privateAccount('cloudflare')).password);
      await form.getByRole('button', { name: 'Next', exact: true }).click({ timeout: 5000 });
    }
    await page.getByRole('button', { name: 'Download', exact: true }).waitFor({ timeout: 10000 });
    const container = page.locator('div.columns-2:visible');
    if (await container.count() !== 1) throw new Error('Expected one recovery-code list.');
    const codes = await container.locator(':scope > div').allTextContents();
    const values = codes.map(code => code.trim());
    if (!validateCloudflareRecoveryCodes(values)) throw new Error('Recovery-code layout changed.');
    const saved = await writePrivateSecretFile(file, JSON.stringify({ savedAt: new Date().toISOString(), codes: values }));
    if (saved.conflict) throw new Error('Different recovery codes already exist locally.');
    await page.getByRole('button', { name: 'Next', exact: true }).click({ timeout: 5000 });
    return { provider: 'cloudflare', saved: true, codeCount: values.length, changed: saved.changed };
  });
}
