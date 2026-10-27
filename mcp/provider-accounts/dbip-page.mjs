// DB-IP owns this projection; browser verification and lifecycle stay in myutils.
import {isIPv4} from 'node:net';
import {mkdtemp, realpath, rmdir} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

/** Match curl's HTTPS route without borrowing the text-browser's default proxy. */
export function dbipPageProxy(env) {
  const proxy = env.https_proxy || env.HTTPS_PROXY || env.all_proxy || env.ALL_PROXY;
  if (!proxy) return undefined;
  const bypass = env.no_proxy || env.NO_PROXY || '';
  if (bypass.split(',').some(item => item.trim() && !['127.0.0.1', 'localhost', '::1'].includes(item.trim())))
    throw Error('route_unsupported');
  let url;
  try { url = new URL(proxy); } catch { throw Error('route_unsupported'); }
  if (!['http:', 'https:', 'socks5:'].includes(url.protocol) || !url.port || url.username || url.password
    || !['', '/'].includes(url.pathname) || url.search || url.hash) throw Error('route_unsupported');
  return `${url.protocol}//${url.host}`;
}

export function dbipPageObservation(result, ip) {
  const failure = {status: 'invalid_response'};
  if (typeof ip !== 'string' || !isIPv4(ip) || !result || result.ok === false || result.httpStatus !== 200 || result.challenge
    || result.url !== `https://db-ip.com/${ip}` || result.cleanupConfirmed !== true
    || result.launchMode !== 'hidden' || result.sessionMode !== 'ephemeral'
    || result.nativeRecovery?.recipe !== 'dbip-public-ip' || result.nativeRecovery.outcome !== 'ready'
    || typeof result.text !== 'string' || result.text.length > 24000 || result.truncated
    || typeof result.title !== 'string' || !result.title.startsWith(`${ip} - `)
    || !Array.isArray(result.headings)) return failure;
  const headings = result.headings.filter(item => item?.level === 'h1');
  if (headings.length !== 1 || headings[0].text !== `${ip} - IP Address Geolocation`
    || result.text.split(/\r?\n/).filter(line => line.trim() === ip).length !== 1) return failure;
  const labels = [...result.text.matchAll(/^Estimated threat level for this IP address is (LOW|MEDIUM|HIGH)\s*$/gmi)];
  if (!labels.length) return {status: 'not_provided'};
  if (labels.length !== 1) return failure;
  return {status: 'ok', ipAddress: ip, threatLevel: labels[0][1].toLowerCase()};
}

export async function readDbipPage(ip, {env = process.env, signal, read} = {}) {
  if (typeof ip !== 'string' || !isIPv4(ip)) return {status: 'route_unsupported'};
  let stateDir;
  try {
    const proxyServer = dbipPageProxy(env);
    if (signal?.aborted) return {status: 'cancelled'};
    // Injected reads are fixture-only; normal calls import the existing shared
    // browser directly, without launching an MCP server or reading account state.
    if (!read) {
      const [{chromium}, {extractBrowserText}] = await Promise.all([
        import('playwright-core'), import('@myutils/web-text/browser-text'),
      ]);
      stateDir = await mkdtemp(path.join(await realpath(tmpdir()), 'ipquality-dbip-page-'));
      const runtime = {chromium, chromiumModulePath: createRequire(import.meta.url).resolve('playwright-core'),
        stateDir, profileDir: path.join(stateDir, 'chrome'), playwrightProfileDir: path.join(stateDir, 'playwright'),
        cdpPort: 19607, leasePort: 19606, proxyServer, signal, keepBrowserOpen: false};
      read = options => extractBrowserText(options, runtime);
    }
    const result = await read({url: `https://db-ip.com/${ip}`, backend: 'real-chrome-cdp',
      timeoutMs: 30000, maxChars: 24000, maxLinks: 0}, {proxyServer, signal});
    const status = result?.httpStatus ?? result?.error?.httpStatus;
    if (status === 429) return {status: 'rate_limited'};
    if (result?.challenge || status === 403) return {status: 'cloudflare_blocked'};
    if (result?.error?.code?.includes('CLEANUP')) return {status: 'cleanup_unverified'};
    if (result?.error?.code?.match(/TIMEOUT|NOT_READY|BUDGET/)) return {status: 'timeout'};
    return dbipPageObservation(result, ip);
  } catch (error) {
    return {status: signal?.aborted ? 'cancelled' : error.message === 'route_unsupported' ? 'route_unsupported'
      : error.code === 'ERR_MODULE_NOT_FOUND' ? 'dependency_missing' : 'browser_unavailable'};
  } finally {
    // Remove only an empty owned parent; uncertain/live profiles must not be erased.
    if (stateDir) await rmdir(stateDir).catch(() => {});
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 3 || process.argv[2] !== '--confirm-network-lookup') {
    console.log(JSON.stringify({status: 'confirmation_required'}));
    process.exitCode = 64;
  } else {
    const abort = new AbortController(), stop = () => abort.abort();
    process.once('SIGINT', stop); process.once('SIGTERM', stop);
    try {
      let input = '';
      for await (const chunk of process.stdin) {
        input += chunk;
        if (input.length > 1024) throw Error('invalid input');
      }
      const request = JSON.parse(input);
      if (!request || Object.keys(request).join() !== 'ip') throw Error('invalid input');
      console.log(JSON.stringify(await readDbipPage(request.ip, {signal: abort.signal})));
    } catch { console.log(JSON.stringify({status: 'invalid_input'})); process.exitCode = 64; }
    finally { process.removeListener('SIGINT', stop); process.removeListener('SIGTERM', stop); }
  }
}
