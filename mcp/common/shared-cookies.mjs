import { request } from 'playwright-core';
import { readSharedChromeCookies, writeSharedChromeCookies } from '@myutils/web-text/shared-chrome';

// Every account login of these MCPs lives in the shared Chrome profile (the text
// browser's saved profile). One HTTP exchange takes the cookies that profile
// would send to `url`; the cookies the site set or removed go back to it, as a
// browser keeps them. Values stay in this process's memory and are never returned.
export async function withSharedCookies(url, proxyServer, operation, dependencies = {}) {
  const readCookies = dependencies.readCookies || readSharedChromeCookies;
  const writeCookies = dependencies.writeCookies || writeSharedChromeCookies;
  const createContext = dependencies.createContext || (options => request.newContext(options));
  const before = await readCookies([url]);
  const context = await createContext({ storageState: { cookies: before, origins: [] },
    ...(proxyServer ? { proxy: { server: proxyServer } } : {}) });
  try {
    const result = await operation(context);
    const changed = changedCookies(before, (await context.storageState()).cookies, new URL(url).hostname);
    if (changed.length) await writeCookies(changed);
    return result;
  } finally { await context.dispose(); }
}

// The cookies of `host`'s domains that `after` added or changed against
// `before`, and the ones it no longer holds as expired entries (a removal).
export function changedCookies(before, after, host) {
  const key = cookie => JSON.stringify([cookie.name, cookie.domain, cookie.path]);
  const site = cookie => {
    const domain = String(cookie.domain).replace(/^\./, '');
    return host === domain || host.endsWith(`.${domain}`);
  };
  const prior = new Map(before.filter(site).map(cookie => [key(cookie), cookie]));
  const present = new Set(), changed = [];
  for (const cookie of after.filter(site)) {
    present.add(key(cookie));
    const old = prior.get(key(cookie));
    if (!old || old.value !== cookie.value || Math.abs(old.expires - cookie.expires) >= 1) changed.push(cookie);
  }
  for (const [name, cookie] of prior) if (!present.has(name)) changed.push({ ...cookie, expires: 1 });
  return changed;
}
