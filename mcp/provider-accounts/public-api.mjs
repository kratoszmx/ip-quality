import { Agent } from 'node:https';
import { requestHttpRead } from '@codex-mcp/shared-http-read';
import { accountNetworkOptions } from './policy.mjs';

const target = '1.1.1.1';
const sources = Object.freeze({
  dbip: { url: `https://api.db-ip.com/v2/free/${target}`, demo: `https://db-ip.com/demo/home.php?s=${target}`, dailyQuota: 500, documentation: 'https://db-ip.com/api/free', website: 'https://db-ip.com/' },
  ipwhois: { url: `https://ipwho.is/${target}`, demo: `https://ipwhois.io/demo?ip=${target}`, dailyQuota: 1000, documentation: 'https://ipwhois.io/documentation', website: 'https://ipwhois.io/' },
});
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const text = value => value == null || (typeof value === 'string' && value.length <= 256 && !/[\u0000-\u001f\u007f]/.test(value));

// The permanent free APIs and website demos have different capabilities.
// Risk fields need a validated demo response for the exact requested IP.
export function publicProviderObservation(provider, body, expected = target, surface = 'free_api') {
  if (!['free_api', 'public_demo'].includes(surface)) return null;
  if (!record(body)) return null;
  if (provider === 'dbip') {
    if (surface === 'public_demo') {
      if (body.status !== 'ok' || !record(body.demoInfo)) return null;
      body = body.demoInfo;
    }
    if (body.error != null || body.errorCode != null || body.ipAddress !== expected ||
        typeof body.countryCode !== 'string' || !/^[A-Z]{2}$/.test(body.countryCode) || ![body.countryName, body.stateProv, body.city].every(text)) return null;
    if (surface === 'public_demo' && body.threatLevel != null && (typeof body.threatLevel !== 'string' || !/^(low|medium|high)$/i.test(body.threatLevel))) return null;
    return { countryCode: body.countryCode, country: body.countryName ?? null, region: body.stateProv ?? null, city: body.city ?? null, attribution: 'IP geolocation by DB-IP (https://db-ip.com/)', ...(surface === 'public_demo' ? { threatLevel: body.threatLevel?.toLowerCase() ?? null } : {}) };
  }
  if (provider === 'ipwhois') {
    if (body.success !== true || body.ip !== expected || typeof body.country_code !== 'string' || !/^[A-Z]{2}$/.test(body.country_code) ||
        !record(body.connection) || !text(body.connection.org) || !text(body.connection.isp) ||
        !['number', 'string'].includes(typeof body.connection.asn) ||
        !/^\d{1,10}$/.test(String(body.connection.asn)) || Number(body.connection.asn) > 4294967295) return null;
    let security;
    if (surface === 'public_demo') {
      if (body.security != null && !record(body.security)) return null;
      security = {};
      for (const key of ['proxy', 'vpn', 'tor', 'hosting']) {
        const value = body.security?.[key];
        if (value != null && typeof value !== 'boolean') return null;
        security[key] = value ?? null;
      }
    }
    return { countryCode: body.country_code, asn: String(body.connection.asn), organization: body.connection.org ?? null, isp: body.connection.isp ?? null, ...(security ? { security } : {}) };
  }
  return null;
}

export async function verifyPublicProvider(provider, confirmation, request = requestHttpRead, surface = 'free_api') {
  if (!Object.hasOwn(sources, provider) || !['free_api', 'public_demo'].includes(surface) || confirmation !== 'VERIFY_FREE_API') throw new Error('Select a supported free provider surface and confirm its one lookup.');
  const source = sources[provider];
  const metadata = { provider, surface, target, requiresAccount: false, twoFactor: 'not_applicable_no_account', documentedDailyQuota: surface === 'free_api' ? source.dailyQuota : null, documentation: surface === 'free_api' ? source.documentation : source.website, riskScoreAvailable: false, riskLabelAvailable: false, riskFactorsAvailable: false };
  const proxy = accountNetworkOptions().proxyServer;
  const agent = new Agent({ proxyEnv: proxy ? { https_proxy: proxy } : {} });
  try {
    const response = await request({ url: surface === 'free_api' ? source.url : source.demo, agent, maxBytes: 65536, timeoutMs: 10000, maxRedirects: 0 });
    if (response.status !== 200) return { ...metadata, usable: false, status: response.status === 429 ? 'rate_limited' : `http_${response.status}` };
    if (!/^application\/(?:json|[a-z0-9.-]+\+json)(?:;|$)/i.test(response.contentType ?? response.headers?.['content-type'] ?? '')) return { ...metadata, usable: false, status: 'invalid_response' };
    let body; try { body = JSON.parse(response.body.toString('utf8')); } catch { return { ...metadata, usable: false, status: 'invalid_response' }; }
    const error = provider === 'dbip' && surface === 'public_demo' ? body?.demoInfo : body;
    if (record(error) && ((provider === 'dbip' && error.errorCode === 'OVER_QUERY_LIMIT') ||
        (provider === 'ipwhois' && error.success === false && typeof error.message === 'string' && /rate limit|too many requests/i.test(error.message)))) {
      return { ...metadata, usable: false, status: 'rate_limited' };
    }
    const observation = publicProviderObservation(provider, body, target, surface);
    return { ...metadata, usable: observation !== null, status: observation ? 'ok' : 'invalid_response',
      ...(observation ? { observation, riskLabelAvailable: observation.threatLevel != null,
        riskFactorsAvailable: Object.values(observation.security ?? {}).some(value => typeof value === 'boolean') } : {}) };
  } catch { return { ...metadata, usable: false, status: 'network_error' }; }
  finally { agent.destroy(); }
}
