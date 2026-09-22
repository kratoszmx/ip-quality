import { providerConfig, assertAccountOrigin } from './policy.mjs';

// Validates the concrete provider form before filling, then reserves the sole
// attempt before submitting. The caller owns private credential persistence.
export async function submitReviewedSignup(page, provider, account, country, reserveAttempt) {
  const config = providerConfig(provider);
  assertAccountOrigin(provider, page.url());
  if (new URL(page.url()).pathname !== config.signup) throw new Error('Unexpected signup page.');
  const form = page.locator('form').filter({ has: page.locator('input[name="email"]') });
  if (await form.count() !== 1) throw new Error('Signup form changed.');
  if ((await form.getAttribute('method') || 'get').toLowerCase() !== 'post') throw new Error('Expected a POST signup form.');
  const action = new URL(await form.getAttribute('action') || page.url(), page.url());
  assertAccountOrigin(provider, action.href);
  if (action.pathname !== config.signup) throw new Error('Signup target changed.');
  const button = form.getByRole('button', { name: config.signupButton, exact: true });
  if (await button.count() !== 1 || !(await button.isEnabled())) throw new Error('Free signup is not ready.');
  await form.locator('input[name="email"]').fill(account.email);
  await form.locator(`input[name="${config.passwordField}"]`).fill(account.password);
  if (provider === 'ipapi') {
    if (!['Hong Kong', 'China'].includes(country)) throw new Error('Country is not confirmed.');
    await form.locator('select[name="country"]').selectOption(country);
  }
  await reserveAttempt();
  await button.click({ timeout: 15_000 });
  // Cloudflare submits asynchronously without a document load. Wait for a
  // changed route or a concrete outcome, never resubmit on an ambiguous timeout.
  await page.waitForFunction(initialPath => location.pathname !== initialPath ||
    /could not complete your registration|verify (?:your )?email|check your inbox|activation link|activate your account|already (?:registered|exists)|invalid|incorrect|unable to/i.test(document.body?.innerText || ''),
  config.signup, { timeout: 15_000 }).catch(() => {});
}
