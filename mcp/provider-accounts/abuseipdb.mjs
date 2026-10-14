import { fileURLToPath } from 'node:url';
import { Agent } from 'node:https';
import { requestHttpRead } from '@myutils/http-read';
import { inspectPrivateSecretFile, readPrivateSecretFile } from '@myutils/secret-file';
import { withSession } from './accounts.mjs';
import { accountNetworkOptions, validApiKey } from './policy.mjs';

const keyPath = fileURLToPath(new URL('../../secrets/abuseipdb', import.meta.url));
const accountPath = fileURLToPath(new URL('../../secrets/accounts/abuseipdb/credentials.json', import.meta.url));
const target = '1.1.1.1';
const keyPolicy = { minBytes: 8, maxBytes: 256, validate: validApiKey };

export function abuseipdbObservation(status, body) {
  if (status !== 200) return { usable: false, status: status === 429 ? 'rate_limited' : `http_${status}` };
  const d = body?.data;
  if (body?.errors != null || !d || Array.isArray(d) || d.ipAddress !== target ||
      !Number.isInteger(d.abuseConfidenceScore) || d.abuseConfidenceScore < 0 || d.abuseConfidenceScore > 100 ||
      typeof d.countryCode !== 'string' || !/^[A-Z]{2}$/.test(d.countryCode)) {
    return { usable: false, status: 'invalid_response' };
  }
  return { usable: true, status: 'ok', target, abuseConfidenceScore: d.abuseConfidenceScore, countryCode: d.countryCode };
}

export async function abuseipdbStatus() {
  const [account, key] = await Promise.all([inspectPrivateSecretFile(accountPath), inspectPrivateSecretFile(keyPath, keyPolicy)]);
  return { provider: 'abuseipdb', accountSaved: account.usable, apiKeySaved: key.usable,
    liveVerified: false, backend: 'http', documentedFreeChecksPerDay: 1000 };
}

export async function verifyAbuseipdb(confirmation, dependencies = {}) {
  if (confirmation !== 'VERIFY_FREE_API') throw new Error('Confirm one free API lookup.');
  const key = await (dependencies.readSecret || readPrivateSecretFile)(keyPath, keyPolicy);
  const proxy = accountNetworkOptions().proxyServer;
  const agent = new Agent({ proxyEnv: proxy ? { https_proxy: proxy } : {} });
  try {
    const response = await (dependencies.request || requestHttpRead)({
      url: `https://api.abuseipdb.com/api/v2/check?ipAddress=${target}&maxAgeInDays=90`,
      headers: { Key: key.secret, Accept: 'application/json' }, agent,
      maxBytes: 65536, timeoutMs: 10000, maxRedirects: 0,
    });
    let body;
    if (/^application\/json\b/i.test(response.contentType || '')) {
      try { body = JSON.parse(response.body.toString('utf8')); } catch { /* invalid below */ }
    }
    return { provider: 'abuseipdb', backend: 'http', ...abuseipdbObservation(response.status, body) };
  } finally { agent.destroy(); }
}

// Only reviewed signup/login surfaces. Account creation, CAPTCHA, key import
// and security settings are explicit maintenance operations, never auto-retried.
export async function openAbuseipdb(surface) {
  if (!['signup', 'login'].includes(surface)) throw new Error('Select signup or login.');
  return withSession('abuseipdb', async page => {
    const response = await page.goto(`https://www.abuseipdb.com/${surface === 'signup' ? 'register' : 'login'}`,
      { waitUntil: 'domcontentloaded', timeout: 20000 });
    const current = new URL(page.url());
    if (current.origin !== 'https://www.abuseipdb.com') throw new Error('Unreviewed account redirect.');
    return { provider: 'abuseipdb', backend: 'headed_chrome', httpStatus: response?.status(),
      path: ['/register', '/login', '/account', '/email/verify'].includes(current.pathname) ? current.pathname : 'unrecognized', submitted: false };
  }, { foreground: true });
}
