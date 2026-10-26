import { inspectPrivateSecretFile, readPrivateSecretFile } from '@myutils/secret-file';

// Restore only the owning site's cookies/storage. A saved file is not proof of
// authentication; each account module must verify its own server identity.
export async function restoreBrowserState(context, stateFile, origin) {
  const present = await inspectPrivateSecretFile(stateFile);
  if (!present.exists) return false;
  const { secret } = await readPrivateSecretFile(stateFile, { minBytes: 2, maxBytes: 2_097_152 });
  const state = JSON.parse(secret);
  if (!Array.isArray(state.cookies) || !Array.isArray(state.origins)) throw new Error('Invalid private browser state.');
  const host = new URL(origin).hostname;
  const cookies = state.cookies.filter(cookie => {
    if (typeof cookie.domain !== 'string') throw new Error('Invalid private cookie scope.');
    const domain = cookie.domain.replace(/^\./, '');
    return host === domain || host.endsWith(`.${domain}`);
  });
  const storage = state.origins.filter(value => value.origin === origin);
  if (storage.length > 1 || storage.some(value => !Array.isArray(value.localStorage) ||
      value.localStorage.some(item => typeof item.name !== 'string' || typeof item.value !== 'string'))) {
    throw new Error('Invalid private origin storage.');
  }
  await context.addCookies(cookies);
  if (storage.length) await context.addInitScript(({ origin, entries }) => {
    if (location.origin === origin) for (const { name, value } of entries) localStorage.setItem(name, value);
  }, { origin, entries: storage[0].localStorage });
  return true;
}
