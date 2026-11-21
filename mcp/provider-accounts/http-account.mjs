import { requestBinaryWithBrowserContext } from '@myutils/browser-session';
import { parseActiveHtmlDocument } from '@myutils/web-text/http-text';
import { DomUtils } from 'htmlparser2';
import { providerConfig, accountNetworkOptions } from './policy.mjs';
import { cloudflareIdentity } from './cloudflare-policy.mjs';
import { withSharedCookies } from '../common/shared-cookies.mjs';

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
  const document = parseActiveHtmlDocument(body, { formEvidence: true });
  const forms = DomUtils.getElementsByTagName('form', document.children);
  if (provider === 'abuseipdb') {
    const basics = forms.filter(form => form.attribs.action === '/account/update-basics');
    const inputs = basics.length === 1 ? DomUtils.getElementsByTagName('input', basics[0].children).map(el => el.attribs) : [];
    const emails = inputs.filter(input => input.name === 'email');
    const authenticated = emails.length === 1 && emails[0].value === expectedEmail &&
      forms.some(form => form.attribs.action === '/logout');
    const privacy = name => {
      const fields = inputs.filter(input => input.name === name && input.type?.toLowerCase() === 'checkbox');
      return authenticated && fields.length === 1 ? Object.hasOwn(fields[0], 'checked') : null;
    };
    return { ...unavailable, authenticated, state: authenticated ? 'authenticated' : 'login_required',
      ...(authenticated ? { emailVerificationPending: DomUtils.existsOne(el =>
        (el.name === 'form' && el.attribs.action === '/account/resend-email-verification')
        || (el.name === 'a' && el.attribs.href === '/account/resend-email-verification'), document.children),
        publicProfile: privacy('public'), publicDomain: privacy('domain-visibility') } : {}) };
  }
  const inputs = DomUtils.getElementsByTagName('input', document.children).map(el => el.attribs);
  const emails = inputs.filter(input => input.name === 'email');
  const authenticated = emails.length === 1 && emails[0].value === expectedEmail &&
    inputs.filter(input => input.name === 'key').length === 1 &&
    !inputs.some(input => input.type?.toLowerCase() === 'password') &&
    DomUtils.existsOne(el => el.name === 'a' && el.attribs.href === '/app/logout', document.children);
  const text = authenticated ? DomUtils.innerText(document.children).replace(/\s+/g, ' ') : '';
  const suspended = /your account has been banned|your account was suspended/i.test(text);
  return { ...unavailable, authenticated, state: suspended ? 'account_suspended' : authenticated ? 'authenticated' : 'login_required',
    ...(suspended ? { apiUsable: false, restriction: /\bbot_login\b/.test(text) ? 'bot_login' : 'account_suspended' } : {}) };
}

// One bounded GET with the shared Chrome profile's cookies for this provider;
// cookies the site refreshes go back to that profile. No page, redirect or retry.
export async function readHttpAccount(provider, expectedEmail, dependencies = {}) {
  const config = providerConfig(provider);
  const url = provider === 'cloudflare' ? `${config.origin}/api/v4/user` : `${config.origin}${config.dashboard}`;
  const read = dependencies.readResponse || requestBinaryWithBrowserContext;
  try {
    const response = await withSharedCookies(url, accountNetworkOptions().proxyServer, context => read({ request: context }, {
      url, headers: { 'Cache-Control': 'no-cache' }, timeoutMs: 15000, maxRedirects: 0,
      maxResponseBytes: 524288, readBodyForStatuses: [200],
    }), dependencies);
    return httpAccountIdentity(provider, response.status, response.contentType, response.body.toString('utf8'), expectedEmail);
  } catch (error) {
    // The shared Chrome could not give or keep the cookies: not a logout.
    const browser = /^(?:SHARED_)?CHROME_/.test(String(error?.code ?? error?.message ?? ''));
    return { provider, backend: 'http', authenticated: false, state: browser ? 'browser_unavailable' : 'session_unavailable',
      nextStep: browser ? 'Run from the owner\'s GUI session so the shared Chrome can start; the login state is unknown, not expired.'
        : 'The HTTP read failed before an account answer; the login state is unknown.' };
  }
}
