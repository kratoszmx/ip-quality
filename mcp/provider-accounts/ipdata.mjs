import { isRecord } from '@myutils/value-shapes';
import { fileURLToPath } from 'node:url';
import { Agent } from 'node:https';
import { request } from 'playwright-core';
import { requestHttpRead } from '@myutils/http-read';
import { inspectPrivateSecretFile, readPrivateSecretFile } from '@myutils/secret-file';
import { readSharedChromeLocalStorage } from '@myutils/web-text/shared-chrome';
import { accountNetworkOptions } from './policy.mjs';

const keyPath = fileURLToPath(new URL('../../secrets/ipdata', import.meta.url));
const accountPath = fileURLToPath(new URL('../../secrets/accounts/ipdata/credentials.json', import.meta.url));
// The dashboard's Amplify session, in its own localStorage of the shared Chrome profile
// (the Cognito app client of the public dashboard web app).
const DASHBOARD = 'https://dashboard.ipdata.co';
const COGNITO = 'CognitoIdentityServiceProvider.d5gbgc9v0lblant4pctftrahe';
const target = '1.1.1.1';
const keyPolicy = { minBytes: 32, maxBytes: 128, validate: value => /^[a-f0-9]{32,128}$/.test(value) };
const factors = ['is_proxy', 'is_vpn', 'is_tor', 'is_datacenter', 'is_threat', 'is_known_abuser', 'is_known_attacker'];

export function ipdataObservation(status, body) {
  if (status !== 200) return { usable: false, status: status === 429 ? 'rate_limited' : `http_${status}` };
  if (!isRecord(body) || body.ip !== target || body.message != null || body.error != null ||
      typeof body.country_code !== 'string' || !/^[A-Z]{2}$/.test(body.country_code) || !isRecord(body.threat) ||
      !factors.every(name => body.threat[name] == null || typeof body.threat[name] === 'boolean') ||
      !factors.some(name => typeof body.threat[name] === 'boolean')) return { usable: false, status: 'invalid_response' };
  return { usable: true, status: 'ok', target, countryCode: body.country_code,
    riskFactors: Object.fromEntries(factors.map(name => [name, body.threat[name] ?? null])) };
}

export async function ipdataStatus(dependencies = {}) {
  const inspect = dependencies.inspectSecret || inspectPrivateSecretFile;
  const [account, key] = await Promise.all([inspect(accountPath, { maxBytes: 4096 }), inspect(keyPath, keyPolicy)]);
  return { provider: 'ipdata', accountSaved: account.usable, apiKeySaved: key.usable,
    loginState: 'shared_chrome_profile', liveVerified: false, backend: 'http' };
}

export async function verifyIpdata(confirmation, dependencies = {}) {
  if (confirmation !== 'VERIFY_FREE_API') throw new Error('Confirm one free API lookup.');
  const key = await (dependencies.readSecret || readPrivateSecretFile)(keyPath, keyPolicy);
  if (!keyPolicy.validate(key.secret)) throw new Error('Invalid private key.');
  const proxy = accountNetworkOptions().proxyServer;
  const agent = new Agent({ proxyEnv: proxy ? { https_proxy: proxy } : {} });
  try {
    const response = await (dependencies.request || requestHttpRead)({
      url: `https://api.ipdata.co/${target}?api-key=${key.secret}`, headers: { Accept: 'application/json' }, agent,
      maxBytes: 262144, timeoutMs: 10000, maxRedirects: 0,
    });
    let body;
    if (/^application\/json\b/i.test(response.contentType || '')) {
      try { body = JSON.parse(response.body.toString('utf8')); } catch { /* invalid below */ }
    }
    return { provider: 'ipdata', backend: 'http', ...ipdataObservation(response.status, body) };
  } catch { return { provider: 'ipdata', backend: 'http', usable: false, status: 'network_error' }; }
  finally { agent.destroy(); }
}

export function ipdataAccountIdentity(status, body, expectedEmail, expectedKey) {
  const unknown = { provider: 'ipdata', backend: 'http', authenticated: false,
    state: status === 400 && body?.__type === 'NotAuthorizedException' ? 'login_required' : 'unconfirmed', httpStatus: status };
  if (status !== 200 || !isRecord(body) || !Array.isArray(body.UserAttributes) || body.UserAttributes.length > 40 ||
      !body.UserAttributes.every(item => isRecord(item) && typeof item.Name === 'string' && typeof item.Value === 'string') ||
      new Set(body.UserAttributes.map(item => item.Name)).size !== body.UserAttributes.length) return unknown;
  const attributes = Object.fromEntries(body.UserAttributes.map(item => [item.Name, item.Value]));
  if (typeof expectedEmail !== 'string' || !expectedEmail || attributes.email !== expectedEmail ||
      !keyPolicy.validate(attributes['custom:api_key'] || '')) return unknown;
  return { ...unknown, authenticated: true, state: 'authenticated', emailVerified: attributes.email_verified === 'true',
    plan: attributes['custom:billing_plan'] === 'free' ? 'free' : 'other', keyMatchesReporter: attributes['custom:api_key'] === expectedKey,
    mfaEnrollmentObserved: Array.isArray(body.UserMFASettingList) && body.UserMFASettingList.some(value => ['SOFTWARE_TOKEN_MFA', 'SMS_MFA'].includes(value)) };
}

// The dashboard uses Cognito GetUser. This read-only POST takes the dashboard's
// access token from the shared Chrome profile, opens no page and never repeats a
// password login or refresh attempt.
export async function checkIpdataAccount(dependencies = {}) {
  let context;
  try {
    const read = dependencies.readSecret || readPrivateSecretFile;
    const readStorage = dependencies.readStorage || readSharedChromeLocalStorage;
    const account = JSON.parse((await read(accountPath, { maxBytes: 4096 })).secret);
    const key = (await read(keyPath, keyPolicy)).secret;
    if (!isRecord(account) || typeof account.email !== 'string' || !account.email || !keyPolicy.validate(key)) throw new Error('Missing private identity.');
    const user = (await readStorage(DASHBOARD, [`${COGNITO}.LastAuthUser`]))[`${COGNITO}.LastAuthUser`];
    if (typeof user !== 'string' || !/^[A-Za-z0-9@._+-]{1,128}$/.test(user)) throw new Error('Missing dashboard session.');
    const tokenName = `${COGNITO}.${user}.accessToken`;
    const token = (await readStorage(DASHBOARD, [tokenName]))[tokenName];
    if (typeof token !== 'string' || !/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token)) throw new Error('Missing session token.');
    const proxy = accountNetworkOptions().proxyServer;
    context = await (dependencies.createContext || (options => request.newContext(options)))(proxy ? { proxy: { server: proxy } } : {});
    const response = await context.post('https://cognito-idp.us-east-1.amazonaws.com/', {
      headers: { 'Content-Type': 'application/x-amz-json-1.1', 'X-Amz-Target': 'AWSCognitoIdentityProviderService.GetUser' },
      data: { AccessToken: token }, maxRedirects: 0, maxRetries: 0, timeout: 10000,
    });
    const status = response.status();
    let body;
    if ([200, 400].includes(status)) {
      const bytes = await response.body();
      if (bytes.length <= 65536 && /^application\/(?:x-amz-json-1\.1|json)\b/i.test(response.headers()['content-type'] || '')) {
        try { body = JSON.parse(bytes.toString('utf8')); } catch { /* unconfirmed below */ }
      }
    }
    return ipdataAccountIdentity(status, body, account.email, key);
  } catch (error) {
    // The shared Chrome could not give the token: not a logout.
    const browser = /^CHROME_/.test(String(error?.code ?? error?.message ?? ''));
    return { provider: 'ipdata', backend: 'http', authenticated: false, state: browser ? 'browser_unavailable' : 'session_unavailable' };
  }
  finally { await context?.dispose().catch(() => {}); }
}
